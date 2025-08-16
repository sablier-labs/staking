// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PRBMathUtils } from "@prb/math/test/utils/Utils.sol";
import { BaseUtils } from "@sablier/evm-utils/src/tests/BaseUtils.sol";

import { Constants } from "./Constants.sol";

abstract contract Utils is Constants, BaseUtils, PRBMathUtils {
    using SafeCast for uint256;

    /// @dev Returns the amount in wei using the token's decimals.
    function amountInWeiForToken(uint128 amount, IERC20 token) internal view returns (uint128) {
        return (amount * 10 ** IERC20Metadata(address(token)).decimals()).toUint128();
    }

    /// @dev Descales the value by dividing it by `SCALE_FACTOR`.
    function getDescaledValue(uint256 value) internal pure returns (uint128) {
        require(value <= MAX_UINT128 * SCALE_FACTOR, "exceeds MAX_UINT128");

        return (value / SCALE_FACTOR).toUint128();
    }

    /// @dev Scales the value by multiplying it by `SCALE_FACTOR`.
    function getScaledValue(uint128 value) internal pure returns (uint256) {
        return uint256(value) * SCALE_FACTOR;
    }

    /// @dev Returns the minimum duration, in seconds, it takes to earn one reward token with `amount` staked.
    function minDurationToEarnOneToken(uint128 amount, uint128 totalStakedAmount) internal pure returns (uint40) {
        return (totalStakedAmount / (uint256(amount) * REWARD_RATE)).toUint40() + 1 seconds;
    }

    /// @dev Returns a random uint40 between `min` and `max`.
    function randomUint40(uint40 min, uint40 max) internal view returns (uint40) {
        return (vm.randomUint({ min: min, max: max })).toUint40();
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
