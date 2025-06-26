// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract OnSablierLockupCancel_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(sablierStaking.onSablierLockupCancel, (streamIds.defaultStream, users.sender, 0, 0));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_CallerNotLockup() external whenNoDelegateCall {
        setMsgSender(users.sender);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_StreamNotStaked.selector, users.sender, streamIds.defaultStream
            )
        );
        sablierStaking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
    }

    function test_RevertGiven_LockupNotWhitelisted() external whenNoDelegateCall whenCallerLockup {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        setMsgSender(address(lockup));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        sablierStaking.onSablierLockupCancel(streamIds.defaultStream, users.sender, 0, 0);
    }

    function test_RevertGiven_StreamNotStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        // Transfer a stream directly to the Staking contract so that its not technically staked.
        setMsgSender(users.recipient);
        lockup.transferFrom(users.recipient, address(sablierStaking), streamIds.defaultStream);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStream);
    }

    function test_GivenStreamStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        uint128 amountToRefund = ISablierLockup(address(lockup)).refundableAmountOf(streamIds.defaultStakedStream);
        uint128 expectedGlobalStakedAmount = sablierStaking.totalAmountStaked(poolIds.defaultPool) - amountToRefund;
        (uint128 previousStreamsCount, uint128 previousStreamAmount, uint128 previousDirectAmount) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT
        );

        // Cancel the stream to trigger the hook.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStakedStream);

        // Check that stream has been canceled.
        assertEq(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStakedStream), true, "stream canceled");

        // It should adjust global staked amount.
        assertEq(
            sablierStaking.totalAmountStaked(poolIds.defaultPool), expectedGlobalStakedAmount, "global staked amount"
        );

        // It should adjust user staked amount.
        (uint128 streamCount, uint128 streamAmountStaked, uint128 directAmountStaked) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);

        assertEq(streamCount, previousStreamsCount, "user streams count");
        assertEq(directAmountStaked, previousDirectAmount, "user direct staked amount");
        assertEq(streamAmountStaked, previousStreamAmount - amountToRefund, "user stream staked amount");
    }
}
