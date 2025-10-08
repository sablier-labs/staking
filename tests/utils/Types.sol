// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

/// @notice A struct to manage the Pool IDs.
/// @param defaultPool The default pool.
/// @param freshPool A pool that has been created but not staked into.
/// @param nullPool A Pool ID that does not exist.
struct PoolIds {
    uint256 defaultPool;
    uint256 freshPool;
    uint256 nullPool;
}

/// @notice A struct to manage the stream IDs.
/// @param defaultStakedStream A cancelable stream that will be staked into the default pool.
/// @param defaultStakedStreamNonCancelable A non-cancelable stream that will be staked into the default pool.
/// @param defaultStream A stream that will is not staked into the default pool.
/// @param differentTokenStream A stream with a different token.
/// @param lockupV12Stream A stream created using Lockup v1.2 contract.
struct StreamIds {
    uint256 defaultStakedStream;
    uint256 defaultStakedStreamNonCancelable;
    uint256 defaultStream;
    uint256 differentTokenStream;
    uint256 lockupV12Stream;
}

/// @notice A struct to manage the test users.
/// @param eve The malicious user.
/// @param poolCreator The default pool creator.
/// @param recipient The default stream recipient who will stake streams as well as direct tokens.
/// @param sender The default stream sender.
/// @param staker The default staker who will stake direct tokens.
struct Users {
    address payable eve;
    address payable poolCreator;
    address payable recipient;
    address payable sender;
    address payable staker;
}

/// @notice A struct to manage test variables, required to prevent stack too deep error.
struct Vars {
    // Actual values.
    uint256 actualRptScaled;
    uint128 actualTotalAmountStaked;
    uint40 actualSnapshotTime;
    // Expected values.
    uint256 expectedRptScaled;
    uint128 expectedTotalAmountStaked;
    uint256 expectedUserRewardsScaled;
}
