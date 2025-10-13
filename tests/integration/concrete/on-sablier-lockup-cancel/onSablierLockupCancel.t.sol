// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract OnSablierLockupCancel_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(sablierStaking.onSablierLockupCancel, (streamIds.defaultStream, users.sender, 0, 0));
        expectRevert_DelegateCall(callData);
    }

    function test_WhenCallerNotLockup() external whenNoDelegateCall {
        setMsgSender(users.sender);

        bytes4 retValue = sablierStaking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
        assertEq(retValue, ISablierLockupRecipient.onSablierLockupCancel.selector, "return value");
    }

    function test_GivenLockupNotWhitelisted() external whenNoDelegateCall whenCallerLockup {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        setMsgSender(address(lockup));

        bytes4 retValue = sablierStaking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
        assertEq(retValue, ISablierLockupRecipient.onSablierLockupCancel.selector, "return value");
    }

    function test_GivenStreamNotStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        // Transfer a stream directly to the Staking contract so that its not technically staked.
        setMsgSender(users.recipient);
        lockup.transferFrom(users.recipient, address(sablierStaking), streamIds.defaultStream);

        uint128 initialTotalStakedAmount = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStream);

        // Check that stream was canceled.
        assertEq(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStream), true, "stream canceled");

        // It should not adjust global staked amount.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), initialTotalStakedAmount, "global staked amount"
        );
    }

    function test_GivenStreamStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        uint128 amountToRefund = ISablierLockup(address(lockup)).refundableAmountOf(streamIds.defaultStakedStream);
        uint128 expectedGlobalStakedAmount = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) - amountToRefund;

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            getScaledValue(REWARDS_EARNED_BY_RECIPIENT)
        );

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStakedStream);

        // Check that stream has been canceled.
        assertEq(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStakedStream), true, "stream canceled");

        // It should adjust global staked amount.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), expectedGlobalStakedAmount, "global staked amount"
        );
    }
}
