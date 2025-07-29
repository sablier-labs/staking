// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IComptrollerable } from "@sablier/evm-utils/src/interfaces/IComptrollerable.sol";
import { ISablierComptroller } from "@sablier/evm-utils/src/interfaces/ISablierComptroller.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";
import { SablierStaking } from "src/SablierStaking.sol";
import { Shared_Integration_Concrete_Test } from "./Concrete.t.sol";

contract Constructor_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_Constructor() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit IComptrollerable.SetComptroller({
            newComptroller: comptroller,
            oldComptroller: ISablierComptroller(address(0))
        });

        // Construct the contract.
        SablierStaking constructedProtocol = new SablierStaking(address(comptroller));

        // {ComptrollerManager.constructor}
        ISablierComptroller actualComptroller = constructedProtocol.comptroller();
        ISablierComptroller expectedComptroller = comptroller;
        assertEq(address(actualComptroller), address(expectedComptroller), "comptroller");

        // {SablierStaking.nextPoolId}
        uint256 actualPoolIds = constructedProtocol.nextPoolId();
        uint256 expectedPoolIds = 1;
        assertEq(actualPoolIds, expectedPoolIds, "nextPoolId");

        // {SablierStaking.supportsInterface}
        assertTrue(
            constructedProtocol.supportsInterface(type(ISablierLockupRecipient).interfaceId),
            "ISablierLockupRecipient interface ID"
        );
    }
}
