// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";

/// @title Helpers
/// @notice Library with helper functions in {SablierStaking} contract.
library Helpers {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // @notice A scale factor of 1e20 is chosen to increase the precision of the rewards calculation.
    uint256 private constant SCALE_FACTOR = 1e20;

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount available in the stream associated with `lockup` contract.
    /// @dev The following function determines the amounts of tokens in a stream irrespective of its cancelable status
    /// using the following formula: stream amount = (amount deposited - amount withdrawn - amount refunded).
    function amountInStream(ISablierLockupNFT lockup, uint256 streamId) internal view returns (uint128 amount) {
        return lockup.getDepositedAmount(streamId) - lockup.getWithdrawnAmount(streamId)
            - lockup.getRefundedAmount(streamId);
    }

    /// @notice Scales down the provided `value` by dividing it by `SCALE_FACTOR`.
    function scaleDown(uint256 value) internal pure returns (uint256) {
        unchecked {
            return value / SCALE_FACTOR;
        }
    }

    /// @notice Scales up the provided `value` by multiplying it by `SCALE_FACTOR`.
    function scaleUp(uint256 value) internal pure returns (uint256) {
        unchecked {
            return value * SCALE_FACTOR;
        }
    }
}
