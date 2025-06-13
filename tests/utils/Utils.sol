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

    /// @dev Descales the value by dividing it by `SCALE_FACTOR`.
    function getDescaledValue(uint256 value) internal pure returns (uint128) {
        require(value <= MAX_UINT128 * SCALE_FACTOR, "exceeds MAX_UINT128");

        return uint128(value / SCALE_FACTOR);
    }

    /// @dev Scales the value by multiplying it by `SCALE_FACTOR`.
    function getScaledValue(uint128 value) internal pure returns (uint256) {
        return uint256(value) * SCALE_FACTOR;
    }

    /// @dev Returns the minimum duration, in seconds, it takes to earn one reward token with `amount` staked.
    function minDurationToEarnOneToken(uint128 amount, uint128 totalAmountStaked) internal pure returns (uint40) {
        return uint40(totalAmountStaked / (uint256(amount) * REWARD_RATE)) + 1 seconds;
    }

    /// @dev Returns a random uint40 between `min` and `max`.
    function randomUint40(uint40 min, uint40 max) internal returns (uint40) {
        return uint40(vm.randomUint({ min: min, max: max }));
    }

    /// @notice Creates an EVM snapshot at the current block timestamp.
    function snapshotState() internal {
        vm.snapshotState();
    }

    /// @dev Warps the EVM state to the latest snapshot before the given timestamp.
    function warpStateTo(uint40 timestamp) internal {
        bool status;
        // If timestamp exceeds `WARP_40_PERCENT`, revert to snapshot 3.
        if (timestamp >= WARP_40_PERCENT) {
            status = vm.revertToState(3);
            require(status, "Failed to revert to snapshot 3");
        }
        // Else if timestamp exceeds `WARP_20_PERCENT`, revert to snapshot 2.
        else if (timestamp >= WARP_20_PERCENT) {
            status = vm.revertToState(2);
            require(status, "Failed to revert to snapshot 2");
        }
        // Else if timestamp exceeds `START_TIME`, revert to snapshot 1.
        else if (timestamp >= START_TIME) {
            status = vm.revertToState(1);
            require(status, "Failed to revert to snapshot 1");
        }
        // Default to `FEB_1_2025` otherwise.
        else {
            status = vm.revertToState(0);
            require(status, "Failed to revert to snapshot 0");
        }

        // Warp to the given timestamp.
        vm.warp(timestamp);
    }
}
