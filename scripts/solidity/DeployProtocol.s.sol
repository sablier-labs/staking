// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { BaseScript } from "@sablier/evm-utils/src/tests/BaseScript.sol";

import { SablierStaking } from "../../src/SablierStaking.sol";

/// @notice Deploys {SablierStaking}.
contract DeployProtocol is BaseScript {
    function run(address initialAdmin) public broadcast returns (SablierStaking sablierStaking) {
        sablierStaking = new SablierStaking(initialAdmin);
    }
}
