// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IAdminable } from "@sablier/evm-utils/src/interfaces/IAdminable.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";
import { SablierStaking } from "src/SablierStaking.sol";
import { Shared_Integration_Concrete_Test } from "./Concrete.t.sol";

contract Constructor_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_Constructor() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit();
        emit IAdminable.TransferAdmin({ oldAdmin: address(0), newAdmin: users.admin });

        // Construct the contract.
        SablierStaking constructedProtocol = new SablierStaking(users.admin);

        // {SablierStaking.nextCampaignId}
        uint256 actualCampaignId = constructedProtocol.nextCampaignId();
        uint256 expectedCampaignId = 1;
        assertEq(actualCampaignId, expectedCampaignId, "nextCampaignId");

        // {Adminable.constructor}
        address actualAdmin = constructedProtocol.admin();
        address expectedAdmin = users.admin;
        assertEq(actualAdmin, expectedAdmin, "admin");

        // {SablierStaking.supportsInterface}
        assertTrue(
            constructedProtocol.supportsInterface(type(ISablierLockupRecipient).interfaceId),
            "ISablierLockupRecipient interface ID"
        );
    }
}
