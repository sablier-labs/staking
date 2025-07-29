// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status } from "src/types/DataTypes.sol";

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

    function test_RevertWhen_FeeNotPaid() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, 0, STAKING_MIN_FEE_WEI)
        );
        sablierStaking.claimRewards(poolIds.defaultPool);
    }

    function test_RevertWhen_ClaimableRewardsZero() external whenNoDelegateCall whenNotNull whenFeePaid {
        // Switch to a different user who has no rewards.
        setMsgSender(users.eve);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_ZeroClaimableRewards.selector, poolIds.defaultPool, users.eve)
        );
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool);
    }

    function test_GivenStatusSCHEDULED()
        external
        whenNoDelegateCall
        whenNotNull
        whenFeePaid
        whenClaimableRewardsNotZero
    {
        // Warp EVM state to 1 second after the end time so that a new round can be started.
        warpStateTo(END_TIME + 1 seconds);

        // Configure the next round.
        configureNextRound();

        // Assert that the status is SCHEDULED.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.SCHEDULED, "status");

        // It should claim rewards.
        _test_claimRewards({
            expectedSnapshotTime: END_TIME + 1 seconds,
            expectedRewardsEarnedPerTokenScaled: REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT_END_TIME
        });
    }

    function test_GivenStatusENDED() external whenNoDelegateCall whenNotNull whenFeePaid whenClaimableRewardsNotZero {
        // Warp EVM state to 1 second after the end time.
        warpStateTo(END_TIME + 1 seconds);

        // Assert that the status is ENDED.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ENDED, "status");

        // It should claim rewards.
        _test_claimRewards({
            expectedSnapshotTime: END_TIME + 1 seconds,
            expectedRewardsEarnedPerTokenScaled: REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT_END_TIME
        });
    }

    function test_GivenStatusACTIVE() external whenNoDelegateCall whenNotNull whenFeePaid whenClaimableRewardsNotZero {
        // It should claim rewards.
        _test_claimRewards({
            expectedSnapshotTime: WARP_40_PERCENT,
            expectedRewardsEarnedPerTokenScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT
        });
    }

    /// @dev Helper function.
    function _test_claimRewards(
        uint40 expectedSnapshotTime,
        uint256 expectedRewardsEarnedPerTokenScaled,
        uint128 expectedRewardsEarnedByRecipient
    )
        private
    {
        uint256 initialCallerBalance = rewardToken.balanceOf(users.recipient);
        uint256 initialContractBalance = rewardToken.balanceOf(address(sablierStaking));

        // It should emit {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            expectedSnapshotTime,
            expectedRewardsEarnedPerTokenScaled,
            users.recipient,
            expectedRewardsEarnedByRecipient
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), users.recipient, expectedRewardsEarnedByRecipient);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClaimRewards(poolIds.defaultPool, users.recipient, expectedRewardsEarnedByRecipient);

        // Claim the rewards.
        setMsgSender(users.recipient);
        uint128 actualRewards = sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool);

        (uint40 actualSnapshotTime, uint256 actualRewardsEarnedPerTokenScaled,) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        // It should set rewards to zero.
        assertEq(sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient), 0, "rewards");

        // It should set last time update to current timestamp.
        assertEq(actualSnapshotTime, expectedSnapshotTime, "lastUpdateTime");

        // It should transfer the rewards to the caller.
        assertEq(
            rewardToken.balanceOf(users.recipient),
            initialCallerBalance + expectedRewardsEarnedByRecipient,
            "recipient balance"
        );
        assertEq(
            rewardToken.balanceOf(address(sablierStaking)),
            initialContractBalance - expectedRewardsEarnedByRecipient,
            "contract balance"
        );

        // It should return the rewards.
        assertEq(actualRewards, expectedRewardsEarnedByRecipient, "return value");

        // It should update the user snapshot correctly.
        assertEq(actualRewardsEarnedPerTokenScaled, expectedRewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");

        // It should deposit fee into the staking pool.
        assertEq(address(sablierStaking).balance, STAKING_MIN_FEE_WEI, "staking pool balance");
    }
}
