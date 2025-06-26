// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClaimRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.claimRewards, (poolIds.defaultPool));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.claimRewards, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Closed() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.claimRewards{ value: FEE }(poolIds.closedPool);
    }

    function test_RevertWhen_FeeNotPaid() external whenNoDelegateCall whenNotNull givenNotClosed {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, 0, FEE));
        sablierStaking.claimRewards(poolIds.defaultPool);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNoDelegateCall whenNotNull givenNotClosed whenFeePaid {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StartTimeInFuture.selector, poolIds.defaultPool, START_TIME)
        );
        sablierStaking.claimRewards{ value: FEE }(poolIds.defaultPool);
    }

    function test_RevertWhen_StartTimeInPresent() external whenNoDelegateCall whenNotNull givenNotClosed whenFeePaid {
        warpStateTo(START_TIME);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_ZeroClaimableRewards.selector, poolIds.defaultPool, users.recipient
            )
        );
        sablierStaking.claimRewards{ value: FEE }(poolIds.defaultPool);
    }

    function test_RevertWhen_ClaimableRewardsZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotClosed
        whenFeePaid
        whenStartTimeInPast
    {
        // Switch to a different user who has no rewards.
        setMsgSender(users.eve);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_ZeroClaimableRewards.selector, poolIds.defaultPool, users.eve)
        );
        sablierStaking.claimRewards{ value: FEE }(poolIds.defaultPool);
    }

    function test_WhenClaimableRewardsNotZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotClosed
        whenFeePaid
        whenStartTimeInPast
    {
        uint256 initialCallerBalance = rewardToken.balanceOf(users.recipient);
        uint256 initialContractBalance = rewardToken.balanceOf(address(sablierStaking));

        // It should emit {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), users.recipient, REWARDS_EARNED_BY_RECIPIENT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClaimRewards(poolIds.defaultPool, users.recipient, REWARDS_EARNED_BY_RECIPIENT);

        // Claim the rewards.
        uint128 actualRewards = sablierStaking.claimRewards{ value: FEE }(poolIds.defaultPool);

        (uint40 lastUpdateTime, uint256 rewardsEarnedPerTokenScaled,) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        // It should set rewards to zero.
        assertEq(sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient), 0, "rewards");

        // It should set last time update to current timestamp.
        assertEq(lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");

        // It should transfer the rewards to the caller.
        assertEq(
            rewardToken.balanceOf(users.recipient),
            initialCallerBalance + REWARDS_EARNED_BY_RECIPIENT,
            "recipient balance"
        );
        assertEq(
            rewardToken.balanceOf(address(sablierStaking)),
            initialContractBalance - REWARDS_EARNED_BY_RECIPIENT,
            "contract balance"
        );

        // It should return the rewards.
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "return value");

        // It should update the user snapshot correctly.
        assertEq(rewardsEarnedPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsEarnedPerTokenScaled");

        // It should deposit fee into the staking pool.
        assertEq(address(sablierStaking).balance, FEE, "staking pool balance");
    }
}
