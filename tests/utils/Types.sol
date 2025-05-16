// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

struct StreamIds {
    // Default cancelable stream.
    uint256 defaultStream;
    // A stream with a different token.
    uint256 defaultStreamWithDifferentToken;
    // A stream that is not allowed to hook with the staking contract.
    uint256 notAllowedToHookStream;
    // A non-cancelable stream.
    uint256 notCancelableStream;
    // A stream ID that does not exist.
    uint256 nullStream;
}

struct Users {
    // Default uer authorized for fee related actions.
    address payable accountant;
    // Default protocol admin.
    address payable admin;
    // Default campaign creator.
    address payable campaignCreator;
    // Malicious user.
    address payable eve;
    // Default stream sender.
    address payable sender;
    // Default staker.
    address payable staker;
}
