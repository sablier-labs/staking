// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title ISablierLockupNFT
/// @notice Interface requirement for Lockup NFT contract to be compatible with the Sablier Staking protocol.
interface ISablierLockupNFT is IERC721 {
    /// @notice Retrieves the amount deposited in the stream, denoted in units of the token's decimals.
    function getDepositedAmount(uint256 streamId) external view returns (uint128 depositedAmount);

    /// @notice Retrieves the amount refunded to the sender after a cancellation, denoted in units of the token's
    /// decimals. This amount is always zero unless the stream was canceled.
    function getRefundedAmount(uint256 streamId) external view returns (uint128 refundedAmount);

    /// @notice Retrieves the address of the underlying ERC-20 token being distributed.
    function getUnderlyingToken(uint256 streamId) external view returns (IERC20 token);

    /// @notice Retrieves the amount withdrawn from the stream, denoted in units of the token's decimals.
    function getWithdrawnAmount(uint256 streamId) external view returns (uint128 withdrawnAmount);

    /// @notice Retrieves a flag indicating whether the provided address is a contract allowed to hook to Sablier
    /// when a stream is canceled or when tokens are withdrawn.
    function isAllowedToHook(address recipient) external view returns (bool result);
}
