// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

/// @notice A struct to manage the stream IDs.
/// @param defaultStream A stream that will is not staked into the default campaign.
/// @param defaultStakedStream A cancelable stream that will be staked into the default campaign.
/// @param defaultStakedStreamNonCancelable A non-cancelable stream that will be staked into the default campaign.
/// @param differentTokenStream A stream with a different token.
/// @param notAllowedToHookStream A stream that is not allowed to hook with the staking contract.
/// @param nullStream A stream ID that does not exist.
struct StreamIds {
    uint256 defaultStream;
    uint256 defaultStakedStream;
    uint256 defaultStakedStreamNonCancelable;
    uint256 differentTokenStream;
    uint256 notAllowedToHookStream;
    uint256 nullStream;
}

/// @notice A struct to manage the test users.
/// @param accountant The default user authorized for fee related actions.
/// @param admin The default protocol admin.
/// @param campaignCreator The default campaign creator.
/// @param eve The malicious user.
/// @param recipient The default stream recipient who will stake streams as well as direct tokens.
/// @param sender The default stream sender.
/// @param staker The default staker who will stake direct tokens.
struct Users {
    address payable accountant;
    address payable admin;
    address payable campaignCreator;
    address payable eve;
    address payable recipient;
    address payable sender;
    address payable staker;
}
