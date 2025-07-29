// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { HandlerStore } from "../stores/HandlerStore.sol";

import { BaseHandler } from "./BaseHandler.sol";

// TODO: Add Lockup related handlers.
contract StakingHandler is BaseHandler {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                      STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Create parameter struct to avoid stack too deep error.
    struct CreateParams {
        uint40 endTime;
        uint40 startTime;
        address poolAdmin;
        uint128 rewardAmount;
        uint256 rewardTokenIndex;
        uint256 stakingTokenIndex;
    }

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

    function passTime(uint256 timeJump) external adjustTimestamp(timeJump) updateHandlerStoreForAllPools { }

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
        updateHandlerStoreForAllPools
        instrument("claimRewards")
    {
        uint128 claimableRewards = sablierStaking.claimableRewards(selectedPoolId, selectedStaker);
        vm.assume(claimableRewards > 0);

        setMsgSender(selectedStaker);
        uint128 rewards = sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(selectedPoolId);

        assert(rewards == claimableRewards);

        // Update handler store.
        handlerStore.addRewardsClaimed(selectedPoolId, selectedStaker, rewards);
    }

    function configureNextRound(
        uint256 timeJump,
        uint256 poolIdIndex,
        uint40 newEndTime,
        uint40 newStartTime,
        uint128 newRewardAmount
    )
        external
        adjustTimestamp(timeJump)
        useFuzzedPool(poolIdIndex)
        updateHandlerStoreForAllPools
        instrument("configureNextRound")
    {
        // Do nothing if the end time is not in the past.
        if (sablierStaking.getEndTime(selectedPoolId) >= getBlockTimestamp()) {
            return;
        }

        // Bound the new start time.
        newStartTime = boundUint40(newStartTime, getBlockTimestamp(), getBlockTimestamp() + 30 days);

        // Bound the new end time.
        newEndTime = boundUint40(newEndTime, newStartTime + 30 days, newStartTime + 365 days);

        // Bound the new reward amount.
        IERC20 rewardToken = sablierStaking.getRewardToken(selectedPoolId);
        newRewardAmount = boundUint128({
            x: newRewardAmount,
            min: amountInWeiForToken(100, rewardToken),
            max: amountInWeiForToken(20_000_000_000, rewardToken)
        });

        address poolAdmin = sablierStaking.getAdmin(selectedPoolId);

        // Deal tokens to the caller and approve the staking pool.
        deal({ token: address(rewardToken), to: poolAdmin, give: newRewardAmount });

        setMsgSender(poolAdmin);
        rewardToken.approve(address(sablierStaking), newRewardAmount);

        // Configure next round.
        sablierStaking.configureNextRound(selectedPoolId, newEndTime, newStartTime, newRewardAmount);

        // Update handler store.
        handlerStore.addTotalRewardsDeposited(selectedPoolId, newRewardAmount);
    }

    function createPool(
        uint256 timeJump,
        CreateParams memory createParams
    )
        external
        adjustTimestamp(timeJump)
        updateHandlerStoreForAllPools
        instrument("createPool")
    {
        vm.assume(createParams.poolAdmin != address(0));

        // Ensure that number of pools created does not exceed the maximum number of pools.
        vm.assume(handlerStore.totalPools() < MAX_POOL_COUNT);

        // Bound the start time.
        createParams.startTime = boundUint40(createParams.startTime, getBlockTimestamp(), getBlockTimestamp() + 30 days);

        // Bound variables to valid values.
        createParams.endTime =
            boundUint40(createParams.endTime, createParams.startTime + 30 days, createParams.startTime + 365 days);
        createParams.rewardTokenIndex = bound(createParams.rewardTokenIndex, 0, tokens.length - 1);
        createParams.stakingTokenIndex = bound(createParams.stakingTokenIndex, 0, tokens.length - 1);

        IERC20 rewardToken = tokens[createParams.rewardTokenIndex];
        IERC20 stakingToken = tokens[createParams.stakingTokenIndex];

        // Bound the reward amount.
        createParams.rewardAmount = boundUint128({
            x: createParams.rewardAmount,
            min: amountInWeiForToken(100, rewardToken),
            max: amountInWeiForToken(20_000_000_000, rewardToken)
        });

        // Deal tokens to the caller and approve the staking pool.
        deal({ token: address(rewardToken), to: createParams.poolAdmin, give: createParams.rewardAmount });

        setMsgSender(createParams.poolAdmin);
        rewardToken.approve(address(sablierStaking), createParams.rewardAmount);

        uint256 poolId = sablierStaking.createPool({
            admin: createParams.poolAdmin,
            endTime: createParams.endTime,
            rewardAmount: createParams.rewardAmount,
            rewardToken: rewardToken,
            stakingToken: stakingToken,
            startTime: createParams.startTime
        });

        // Add the pool ID to the handler store.
        handlerStore.addPoolId(poolId);

        // Update handler store.
        handlerStore.addTotalRewardsDeposited(poolId, createParams.rewardAmount);
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
        updateHandlerStoreForAllPools
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
        updateHandlerStoreForAllPools
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
        amount = boundUint128(amount, 1, amountInWeiForToken(1_000_000_000, stakingToken));

        // Deal tokens to the staker and approve the staking pool.
        deal({ token: address(stakingToken), to: selectedStaker, give: amount });

        setMsgSender(selectedStaker);
        stakingToken.approve(address(sablierStaking), amount);

        sablierStaking.stakeERC20Token(selectedPoolId, amount);

        // Update handler store.
        handlerStore.addUserStake(selectedPoolId, selectedStaker, amount);
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
        updateHandlerStoreForAllPools
        instrument("unstakeERC20Token")
    {
        uint128 amountStakedByUser = handlerStore.amountStaked(selectedPoolId, selectedStaker);

        // Check that staker has amount staked.
        vm.assume(amountStakedByUser > 0);

        amount = boundUint128(amount, 1, amountStakedByUser);

        setMsgSender(selectedStaker);
        sablierStaking.unstakeERC20Token(selectedPoolId, amount);

        // Update handler store.
        handlerStore.subtractUserStake(selectedPoolId, selectedStaker, amount);
    }
}
