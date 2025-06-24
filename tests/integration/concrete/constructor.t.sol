// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IComptrollerManager } from "@sablier/evm-utils/src/interfaces/IComptrollerManager.sol";
import { ISablierComptroller } from "@sablier/evm-utils/src/interfaces/ISablierComptroller.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";
import { SablierStaking } from "src/SablierStaking.sol";
import { Shared_Integration_Concrete_Test } from "./Concrete.t.sol";

contract Constructor_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_Constructor() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit IComptrollerManager.SetComptroller({
            newComptroller: comptroller,
            oldComptroller: ISablierComptroller(address(0))
        });

        // Construct the contract.
        SablierStaking constructedProtocol = new SablierStaking(address(comptroller));

        // {ComptrollerManager.constructor}
        ISablierComptroller actualComptroller = constructedProtocol.comptroller();
        ISablierComptroller expectedComptroller = comptroller;
        assertEq(address(actualComptroller), address(expectedComptroller), "comptroller");

        // {SablierStaking.LOCKUP_WHITELIST_ROLE}
        assertEq(constructedProtocol.LOCKUP_WHITELIST_ROLE(), keccak256("LOCKUP_WHITELIST_ROLE"), "whitelist role");

        // {SablierStaking.nextCampaignId}
        uint256 actualCampaignId = constructedProtocol.nextCampaignId();
        uint256 expectedCampaignId = 1;
        assertEq(actualCampaignId, expectedCampaignId, "nextCampaignId");

        // {SablierStaking.supportsInterface}
        assertTrue(
            constructedProtocol.supportsInterface(type(ISablierLockupRecipient).interfaceId),
            "ISablierLockupRecipient interface ID"
        );
    }
}
