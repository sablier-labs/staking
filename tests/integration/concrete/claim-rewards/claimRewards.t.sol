// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ud, UD60x18 } from "@prb/math/src/UD60x18.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status, UserAccount } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClaimRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.claimRewards, (poolIds.defaultPool, FEE_ON_REWARDS));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.claimRewards, (poolIds.nullPool, FEE_ON_REWARDS));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_MinFeeNotPaid() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, 0, STAKING_MIN_FEE_WEI)
        );
        sablierStaking.claimRewards(poolIds.defaultPool, FEE_ON_REWARDS);
    }

    function test_RevertWhen_FeeOnRewardsTooHigh() external whenNoDelegateCall whenNotNull whenMinFeePaid {
        // Set the fee on rewards so that it exceeds the max fee.
        UD60x18 feeOnRewards = MAX_FEE_ON_REWARDS.add(ud(1));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_FeeOnRewardsTooHigh.selector, feeOnRewards, MAX_FEE_ON_REWARDS)
        );
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool, feeOnRewards);
    }

    function test_RevertGiven_ClaimableRewardsZero()
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        whenFeeOnRewardsNotTooHigh
    {
        // Switch to a different user who has no rewards.
        setMsgSender(users.eve);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_ZeroClaimableRewards.selector, poolIds.defaultPool, users.eve)
        );
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool, FEE_ON_REWARDS);
    }

    function test_GivenStatusSCHEDULED()
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        whenFeeOnRewardsNotTooHigh
        givenClaimableRewardsNotZero
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
            expectedRptEarnedScaled: REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT_END_TIME
        });
    }

    function test_GivenStatusENDED()
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        whenFeeOnRewardsNotTooHigh
        givenClaimableRewardsNotZero
    {
        // Warp EVM state to 1 second after the end time.
        warpStateTo(END_TIME + 1 seconds);

        // Assert that the status is ENDED.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ENDED, "status");

        // It should claim rewards.
        _test_claimRewards({
            expectedSnapshotTime: END_TIME + 1 seconds,
            expectedRptEarnedScaled: REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT_END_TIME
        });
    }

    function test_GivenStatusACTIVE()
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        whenFeeOnRewardsNotTooHigh
        givenClaimableRewardsNotZero
    {
        // It should claim rewards.
        _test_claimRewards({
            expectedSnapshotTime: WARP_40_PERCENT,
            expectedRptEarnedScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedRewardsEarnedByRecipient: REWARDS_EARNED_BY_RECIPIENT
        });
    }

    /// @dev Helper function.
    function _test_claimRewards(
        uint40 expectedSnapshotTime,
        uint256 expectedRptEarnedScaled,
        uint128 expectedRewardsEarnedByRecipient
    )
        private
    {
        uint256 initialCallerBalance = rewardToken.balanceOf(users.recipient);
        uint256 initialContractBalance = rewardToken.balanceOf(address(sablierStaking));
        uint256 initialComptrollerBalance = rewardToken.balanceOf(address(comptroller));
        uint256 initialComptrollerEthBalance = address(comptroller).balance;

        uint128 expectedRewardsTransferredToComptroller =
            ud(expectedRewardsEarnedByRecipient).mul(FEE_ON_REWARDS).intoUint128();
        uint128 expectedRewardsTransferredToRecipient =
            expectedRewardsEarnedByRecipient - expectedRewardsTransferredToComptroller;

        // It should emit 1 {SnapshotRewards}, 2 {Transfer} and 1 {ClaimRewards} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            expectedSnapshotTime,
            expectedRptEarnedScaled,
            users.recipient,
            getScaledValue(expectedRewardsEarnedByRecipient)
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), address(comptroller), expectedRewardsTransferredToComptroller);
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), users.recipient, expectedRewardsTransferredToRecipient);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClaimRewards(poolIds.defaultPool, users.recipient, expectedRewardsTransferredToRecipient);

        // Claim the rewards.
        setMsgSender(users.recipient);
        uint128 actualRewards =
            sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool, FEE_ON_REWARDS);

        UserAccount memory userAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);

        // It should update the user snapshot correctly.
        assertEq(userAccount.snapshotRptEarnedScaled, expectedRptEarnedScaled, "rptEarnedScaled");

        // It should set rewards to zero.
        assertEq(sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient), 0, "rewards");

        // It should transfer the min fee to comptroller.
        assertEq(
            address(comptroller).balance, initialComptrollerEthBalance + STAKING_MIN_FEE_WEI, "comptroller ETH balance"
        );

        // It should transfer the rewards to the caller.
        assertEq(
            rewardToken.balanceOf(users.recipient),
            initialCallerBalance + expectedRewardsTransferredToRecipient,
            "recipient balance"
        );
        assertEq(
            rewardToken.balanceOf(address(comptroller)),
            initialComptrollerBalance + expectedRewardsTransferredToComptroller,
            "comptroller balance"
        );
        assertEq(
            rewardToken.balanceOf(address(sablierStaking)),
            initialContractBalance - expectedRewardsEarnedByRecipient,
            "contract balance"
        );

        // It should return the rewards.
        assertEq(actualRewards, expectedRewardsTransferredToRecipient, "return value");
    }
}
