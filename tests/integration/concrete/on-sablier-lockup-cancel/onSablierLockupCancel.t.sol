// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Amounts } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract OnSablierLockupCancel_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(staking.onSablierLockupCancel, (streamIds.defaultStream, users.sender, 0, 0));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_CallerNotLockup() external whenNoDelegateCall {
        setMsgSender(users.sender);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_StreamNotStaked.selector, users.sender, streamIds.defaultStream
            )
        );
        staking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
    }

    function test_RevertGiven_LockupNotWhitelisted() external whenNoDelegateCall whenCallerLockup {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        setMsgSender(address(lockup));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        staking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
    }

    function test_RevertGiven_StreamNotStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        // Transfer a stream directly to the Staking contract so that its not technically staked.
        setMsgSender(users.recipient);
        lockup.transferFrom(users.recipient, address(staking), streamIds.defaultStream);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStream);
    }

    function test_GivenStreamStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        uint128 amountToRefund = ISablierLockup(address(lockup)).refundableAmountOf(streamIds.defaultStakedStream);
        uint128 expectedGlobalStakedAmount = staking.totalAmountStaked(campaignIds.defaultCampaign) - amountToRefund;
        Amounts memory amountStakedByRecipient =
            staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        uint128 expectedTotalAmountStakedByRecipient = amountStakedByRecipient.totalAmountStaked - amountToRefund;
        uint128 expectedDirectAmountStakedByRecipient = amountStakedByRecipient.directAmountStaked;
        uint128 expectedStreamAmountStakedByRecipient = amountStakedByRecipient.streamAmountStaked - amountToRefund;
        uint128 expectedStreamsCountByRecipient = amountStakedByRecipient.streamsCount;

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            WARP_40_PERCENT,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN),
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT,
            AMOUNT_STAKED_BY_RECIPIENT
        );

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStakedStream);

        // Check that stream has been canceled.
        assertEq(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStakedStream), true, "stream canceled");

        // It should adjust global staked amount.
        assertEq(
            staking.totalAmountStaked(campaignIds.defaultCampaign), expectedGlobalStakedAmount, "global staked amount"
        );

        // It should adjust user staked amount.
        Amounts memory actualAmountStakedByRecipient =
            staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        assertEq(
            actualAmountStakedByRecipient.totalAmountStaked,
            expectedTotalAmountStakedByRecipient,
            "user total staked amount"
        );
        assertEq(
            actualAmountStakedByRecipient.directAmountStaked,
            expectedDirectAmountStakedByRecipient,
            "user direct staked amount"
        );
        assertEq(
            actualAmountStakedByRecipient.streamAmountStaked,
            expectedStreamAmountStakedByRecipient,
            "user stream staked amount"
        );
        assertEq(actualAmountStakedByRecipient.streamsCount, expectedStreamsCountByRecipient, "user streams count");
    }
}
