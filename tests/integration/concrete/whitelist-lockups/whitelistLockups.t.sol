// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors as ComptrollerErrors } from "@sablier/evm-utils/src/libraries/Errors.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import {
    LockupWithoutGetAssetOrGetUnderlyingToken,
    LockupWithoutGetDepositedAmount,
    LockupWithoutGetRefundedAmount,
    LockupWithoutGetWithdrawnAmount
} from "../../../mocks/LockupMocks.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract WhitelistLockups_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    /// @dev An array to hold Lockup addresses including Lockup v1.2.
    ISablierLockupNFT[] private lockups;

    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        // Deploy two new Lockups and add them to the list.
        lockups.push(deployLockupAndCreateStream());
        lockups.push(deployLockupAndCreateStream());

        // Add Lockup v1.2 it to the list.
        lockups.push(deployLockupV12AndCreateStream());

        // Set allow to hook.
        setMsgSender(address(comptroller));
        ISablierLockup(address(lockups[0])).allowToHook(address(sablierStaking));
        ISablierLockup(address(lockups[1])).allowToHook(address(sablierStaking));
        ISablierLockup(address(lockups[2])).allowToHook(address(sablierStaking));
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.whitelistLockups, (lockups));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_CallerNotComptroller() external whenNoDelegateCall {
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                ComptrollerErrors.Comptrollerable_CallerNotComptroller.selector, comptroller, users.eve
            )
        );
        sablierStaking.whitelistLockups(lockups);
    }

    function test_RevertGiven_AlreadyWhitelisted() external whenNoDelegateCall whenCallerComptroller {
        lockups.push(lockup);

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_LockupAlreadyWhitelisted.selector, lockup));
        sablierStaking.whitelistLockups(lockups);
    }

    function test_RevertWhen_LockupNotImplementRequiredInterface()
        external
        whenNoDelegateCall
        whenCallerComptroller
        givenNotWhitelisted
    {
        // Deploy mock Lockup contracts missing one or more required functions.
        address lockupWithoutAnyTokenGetter = address(new LockupWithoutGetAssetOrGetUnderlyingToken());
        address lockupWithoutGetDepositedAmount = address(new LockupWithoutGetDepositedAmount());
        address lockupWithoutGetRefundedAmount = address(new LockupWithoutGetRefundedAmount());
        address lockupWithoutGetWithdrawnAmount = address(new LockupWithoutGetWithdrawnAmount());

        // It should revert when neither `getAsset` or `getUnderlying` function is implemented.
        lockups.push(ISablierLockupNFT(lockupWithoutAnyTokenGetter));
        _expectRevertWithSelector(ISablierLockupNFT.getAsset.selector);

        // It should revert when `getDepositedAmount` function is not implemented.
        lockups[3] = ISablierLockupNFT(lockupWithoutGetDepositedAmount);
        _expectRevertWithSelector(ISablierLockupNFT.getDepositedAmount.selector);

        // It should revert when `getRefundedAmount` function is not implemented.
        lockups[3] = ISablierLockupNFT(lockupWithoutGetRefundedAmount);
        _expectRevertWithSelector(ISablierLockupNFT.getRefundedAmount.selector);

        // It should revert when `getWithdrawnAmount` function is not implemented.
        lockups[3] = ISablierLockupNFT(lockupWithoutGetWithdrawnAmount);
        _expectRevertWithSelector(ISablierLockupNFT.getWithdrawnAmount.selector);
    }

    function test_RevertWhen_IsAllowedToHookReturnsFalse()
        external
        whenNoDelegateCall
        whenCallerComptroller
        givenNotWhitelisted
        whenLockupImplementsRequiredInterface
    {
        // Deploy a new Lockup contract and add it to the list without setting allow to hook.
        lockups.push(deployLockupAndCreateStream());

        // Revert back the caller to comptroller.
        setMsgSender(address(comptroller));

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_UnsupportedOnAllowedToHook.selector, lockups[3]));
        sablierStaking.whitelistLockups(lockups);
    }

    function test_WhenIsAllowedToHookReturnsTrue()
        external
        whenNoDelegateCall
        whenCallerComptroller
        givenNotWhitelisted
        whenLockupImplementsRequiredInterface
    {
        // It should emit {LockupWhitelisted} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.LockupWhitelisted(address(comptroller), lockups[0]);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.LockupWhitelisted(address(comptroller), lockups[1]);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.LockupWhitelisted(address(comptroller), lockups[2]);

        // Whitelist the lockups.
        sablierStaking.whitelistLockups(lockups);

        // It should whitelist lockup.
        assertEq(sablierStaking.isLockupWhitelisted(lockups[0]), true);
        assertEq(sablierStaking.isLockupWhitelisted(lockups[1]), true);
        assertEq(sablierStaking.isLockupWhitelisted(lockups[2]), true);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _expectRevertWithSelector(bytes4 selector) private {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_LockupMissesSelector.selector, lockups[3], selector)
        );
        sablierStaking.whitelistLockups(lockups);
    }
}
