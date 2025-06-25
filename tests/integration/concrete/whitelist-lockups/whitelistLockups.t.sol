// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors as ComptrollerErrors } from "@sablier/evm-utils/src/libraries/Errors.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract WhitelistLockups_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    ISablierLockupNFT[] private lockups;

    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        // Deploy two new Lockups and add them to the list.
        lockups.push(deployLockup());
        lockups.push(deployLockup());

        // Set allow to hook.
        setMsgSender(address(comptroller));
        ISablierLockup(address(lockups[0])).allowToHook(address(stakingPool));
        ISablierLockup(address(lockups[1])).allowToHook(address(stakingPool));
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(stakingPool.whitelistLockups, (lockups));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_CallerNotComptroller() external whenNoDelegateCall {
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                ComptrollerErrors.ComptrollerManager_CallerNotComptroller.selector, comptroller, users.eve
            )
        );
        stakingPool.whitelistLockups(lockups);
    }

    function test_RevertWhen_ZeroAddress() external whenNoDelegateCall whenCallerComptroller {
        // Add a zero address to the list.
        lockups.push(ISablierLockupNFT(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_LockupZeroAddress.selector, 2));
        stakingPool.whitelistLockups(lockups);
    }

    function test_RevertGiven_AlreadyWhitelisted()
        external
        whenNoDelegateCall
        whenCallerComptroller
        whenNotZeroAddress
    {
        lockups.push(lockup);

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_LockupAlreadyWhitelisted.selector, 2, lockup));
        stakingPool.whitelistLockups(lockups);
    }

    function test_RevertWhen_IsAllowedToHookReturnsFalse()
        external
        whenNoDelegateCall
        whenCallerComptroller
        whenNotZeroAddress
        givenNotWhitelisted
    {
        // Deploy a new Lockup contract and add it to the list without setting allow to hook.
        lockups.push(deployLockup());

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_UnsupportedOnAllowedToHook.selector, 2, lockups[2])
        );
        stakingPool.whitelistLockups(lockups);
    }

    function test_WhenIsAllowedToHookReturnsTrue()
        external
        whenNoDelegateCall
        whenCallerComptroller
        whenNotZeroAddress
        givenNotWhitelisted
    {
        _test_WhitelistLockups();
    }

    /// @dev Helper function to test the whitelisting function.
    function _test_WhitelistLockups() private {
        // It should emit {LockupWhitelisted} event.
        vm.expectEmit({ emitter: address(stakingPool) });
        emit ISablierStaking.LockupWhitelisted(address(comptroller), lockups[0]);
        vm.expectEmit({ emitter: address(stakingPool) });
        emit ISablierStaking.LockupWhitelisted(address(comptroller), lockups[1]);

        // Whitelist the lockups.
        stakingPool.whitelistLockups(lockups);

        // It should whitelist lockup.
        assertEq(stakingPool.isLockupWhitelisted(lockups[0]), true);
        assertEq(stakingPool.isLockupWhitelisted(lockups[1]), true);
    }
}
