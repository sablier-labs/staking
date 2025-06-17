// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract OnSablierLockupWithdraw_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            staking.onSablierLockupWithdraw, (streamIds.defaultStream, users.recipient, users.recipient, 0)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_CallerNotLockup() external whenNoDelegateCall {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_StreamNotStaked.selector, users.recipient, streamIds.defaultStream
            )
        );
        staking.onSablierLockupWithdraw(streamIds.defaultStream, users.recipient, users.recipient, 0);
    }

    function test_RevertGiven_LockupNotWhitelisted() external whenNoDelegateCall whenCallerLockup {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        setMsgSender(address(lockup));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        staking.onSablierLockupWithdraw(streamIds.defaultStream, users.recipient, users.recipient, 0);
    }

    function test_RevertGiven_StreamNotStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        // Transfer a stream directly to the Staking contract so that its not technically staked.
        lockup.transferFrom(users.recipient, address(staking), streamIds.defaultStream);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );

        // Withdraw from the stream to trigger the hook.
        ISablierLockup(address(lockup)).withdrawMax(streamIds.defaultStream, address(staking));
    }

    function test_RevertGiven_StreamStaked() external whenNoDelegateCall whenCallerLockup givenLockupWhitelisted {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_WithdrawNotAllowed.selector,
                campaignIds.defaultCampaign,
                lockup,
                streamIds.defaultStakedStream
            )
        );

        // Withdraw from the stream to trigger the hook.
        ISablierLockup(address(lockup)).withdrawMax(streamIds.defaultStakedStream, address(staking));
    }
}
