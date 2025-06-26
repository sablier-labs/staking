// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { HandlerStore } from "../stores/HandlerStore.sol";

import { BaseHandler } from "./BaseHandler.sol";

contract StakingHandler is BaseHandler {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(
        HandlerStore handlerStore_,
        ISablierStaking sablierStaking_,
        IERC20[] memory tokens_
    )
        BaseHandler(handlerStore_, sablierStaking_, tokens_)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                  GENERIC HANDLERS
    //////////////////////////////////////////////////////////////////////////*/

    function passTime(uint256 timeJump) external adjustTimestamp(timeJump) updateRewardsDistributedForAllPools { }

    /*//////////////////////////////////////////////////////////////////////////
                                  BOUNDED HANDLERS
    //////////////////////////////////////////////////////////////////////////*/

    function claimRewards(
        uint256 timeJump,
        uint256 poolIdIndex,
        uint256 stakerIndex
    )
        external
        adjustTimestamp(timeJump)
        useFuzzedPool(poolIdIndex)
        useFuzzedStaker(stakerIndex)
        updateRewardsDistributedForAllPools
        instrument("claimRewards")
    {
        uint128 claimableRewards = sablierStaking.claimableRewards(selectedPoolId, selectedStaker);
        vm.assume(claimableRewards > 0);

        setMsgSender(selectedStaker);
        uint128 rewards = sablierStaking.claimRewards{ value: FEE }(selectedPoolId);

        assert(rewards == claimableRewards);

        // Update handler store.
        handlerStore.updateRewardsClaimed(selectedPoolId, selectedStaker, rewards);
        handlerStore.updateUserSnapshotTime(selectedPoolId, selectedStaker, getBlockTimestamp());
    }

    function createPool(
        uint256 timeJump,
        uint40 endTime,
        address poolAdmin,
        uint256 rewardTokenIndex,
        uint256 stakingTokenIndex,
        uint128 totalRewards
    )
        external
        adjustTimestamp(timeJump)
        updateRewardsDistributedForAllPools
        instrument("createPool")
    {
        vm.assume(poolAdmin != address(0));

        // Ensure that number of pools created does not exceed the maximum number of pools.
        vm.assume(handlerStore.totalPools() < MAX_POOL_COUNT);

        // Set the start time to the current block timestamp.
        uint40 startTime = getBlockTimestamp();

        // Bound variables to valid values.
        endTime = boundUint40(endTime, startTime + 1 seconds, startTime + 3650 days);
        rewardTokenIndex = bound(rewardTokenIndex, 0, tokens.length - 1);
        stakingTokenIndex = bound(stakingTokenIndex, 0, tokens.length - 1);

        IERC20 rewardToken = tokens[rewardTokenIndex];
        IERC20 stakingToken = tokens[stakingTokenIndex];

        // Bound the total rewards.
        totalRewards = boundUint128({
            x: totalRewards,
            min: amountInWei(100, rewardToken),
            max: amountInWei(20_000_000_000, rewardToken)
        });

        // Deal tokens to the caller and approve the staking pool.
        deal({ token: address(rewardToken), to: poolAdmin, give: totalRewards });

        setMsgSender(poolAdmin);
        rewardToken.approve(address(sablierStaking), totalRewards);

        uint256 poolId = sablierStaking.createPool({
            admin: poolAdmin,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: totalRewards
        });

        // Add the pool ID to the handler store.
        handlerStore.addPoolId(poolId);
    }

    function snapshotRewards(
        uint256 timeJump,
        uint256 poolIdIndex,
        uint256 stakerIndex
    )
        external
        adjustTimestamp(timeJump)
        useFuzzedPool(poolIdIndex)
        useFuzzedStaker(stakerIndex)
        updateRewardsDistributedForAllPools
        instrument("snapshotRewards")
    {
        uint40 lastSnapshotTime = handlerStore.userSnapshotTime(selectedPoolId, selectedStaker);
        uint40 endTime = sablierStaking.getEndTime(selectedPoolId);
        uint128 amountStakedByUser = handlerStore.amountStaked(selectedPoolId, selectedStaker);

        // Do nothing if the following conditions are met.
        if (lastSnapshotTime >= endTime || amountStakedByUser == 0) {
            return;
        }

        sablierStaking.snapshotRewards(selectedPoolId, selectedStaker);

        // Update handler store.
        handlerStore.updateUserSnapshotTime(selectedPoolId, selectedStaker, getBlockTimestamp());
    }

    function stakeERC20Token(
        uint256 timeJump,
        uint128 amount,
        bool isNewStaker,
        uint256 poolIdIndex,
        uint256 stakerIndex
    )
        external
        adjustTimestamp(timeJump)
        useFuzzedPool(poolIdIndex)
        useFuzzedStaker(stakerIndex)
        updateRewardsDistributedForAllPools
        instrument("stakeERC20Token")
    {
        // Do nothing if end time is not in the future.
        if (sablierStaking.getEndTime(selectedPoolId) <= getBlockTimestamp()) {
            return;
        }

        if (isNewStaker) {
            // Create a new user.
            selectedStaker = vm.randomAddress();

            // Update handler store.
            handlerStore.addStaker(selectedPoolId, selectedStaker);
        }

        IERC20 stakingToken = sablierStaking.getStakingToken(selectedPoolId);
        amount = boundUint128(amount, 1, amountInWei(1_000_000_000, stakingToken));

        // Deal tokens to the staker and approve the staking pool.
        deal({ token: address(stakingToken), to: selectedStaker, give: amount });

        setMsgSender(selectedStaker);
        stakingToken.approve(address(sablierStaking), amount);

        sablierStaking.stakeERC20Token(selectedPoolId, amount);

        // Update handler store.
        handlerStore.increaseUserStake(selectedPoolId, selectedStaker, amount);
        handlerStore.updateUserSnapshotTime(selectedPoolId, selectedStaker, getBlockTimestamp());
    }

    function unstakeERC20Token(
        uint256 timeJump,
        uint128 amount,
        uint256 poolIdIndex,
        uint256 stakerIndex
    )
        external
        adjustTimestamp(timeJump)
        useFuzzedPool(poolIdIndex)
        useFuzzedStaker(stakerIndex)
        updateRewardsDistributedForAllPools
        instrument("unstakeERC20Token")
    {
        uint128 amountStakedByUser = handlerStore.amountStaked(selectedPoolId, selectedStaker);

        // Check that staker has amount staked.
        vm.assume(amountStakedByUser > 0);

        amount = boundUint128(amount, 1, amountStakedByUser);

        setMsgSender(selectedStaker);
        sablierStaking.unstakeERC20Token(selectedPoolId, amount);

        // Update handler store.
        handlerStore.decreaseUserStake(selectedPoolId, selectedStaker, amount);
        handlerStore.updateUserSnapshotTime(selectedPoolId, selectedStaker, getBlockTimestamp());
    }
}
