// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { BaseScript } from "@sablier/evm-utils/src/tests/BaseScript.sol";

import { SablierStaking } from "../../src/SablierStaking.sol";

/// @notice Deploys {SablierStaking} at a deterministic address across chains.
/// @dev Reverts if the contract has already been deployed.
contract DeployDeterministicProtocol is BaseScript {
    function run(address initialAdmin) public broadcast returns (SablierStaking stakingPool) {
        bytes32 salt = constructCreate2Salt();

        stakingPool = new SablierStaking{ salt: salt }(initialAdmin);
    }
}
