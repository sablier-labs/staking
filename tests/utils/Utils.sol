// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { BaseTest as EvmUtilsBase } from "@sablier/evm-utils/src/tests/BaseTest.sol";
import { SablierStaking } from "src/SablierStaking.sol";

import { Constants } from "./Constants.sol";

abstract contract Utils is Constants, EvmUtilsBase {
    /// @dev Deploys {SablierStaking} from an optimized source compiled with `--via-ir`.
    function deployOptimizedSablierStaking(address admin) internal returns (SablierStaking) {
        return SablierStaking(deployCode("out-optimized/SablierStaking.sol/SablierStaking.json", abi.encode(admin)));
    }
}
