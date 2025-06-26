// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * This file defines all structs used in this Sablier Staking contract. You will notice that some structs contain "slot"
 * annotations - they are used to indicate the storage layout of the struct. It is more gas efficient to group small
 * data types together so that they fit in a single 32-byte slot.
 */

/// @notice A data structure to store the total rewards snapshot data for each pool.
/// @param lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
/// @param rewardsDistributedPerTokenScaled The amount of rewards distributed per staking token (includes both direct
/// staking and through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
struct GlobalSnapshot {
    // Slot 0
    uint40 lastUpdateTime;
    // Slot 1
    uint256 rewardsDistributedPerTokenScaled;
}

/// @notice A data structure to store the pool parameters.
/// @param admin The admin of the staking pool. This may be different from the pool creator.
/// @param rewardToken The address of the ERC20 token to used as staking rewards.
/// @param stakingToken The address of the ERC20 token that can be staked either directly or through Sablier stream.
/// @param wasClosed Boolean indicating if the pool was closed.
/// @param endTime The end time of the rewards period, denoted in UNIX timestamp.
/// @param startTime The start time of the rewards period, denoted in UNIX timestamp.
/// @param totalRewards The amount of total rewards to be distributed during the rewards period, denoted in reward
/// token's decimals.
struct Pool {
    // Slot 0
    address admin;
    // Slot 1
    IERC20 rewardToken;
    // Slot 2
    IERC20 stakingToken;
    // Slot 3
    bool wasClosed;
    uint40 endTime;
    uint40 startTime;
    uint128 totalRewards;
}

/// @notice A data structure to reverse lookup from a Lockup stream ID to the pool ID and original stream owner.
/// @param owner The original owner of the stream.
/// @param poolId The ID of the staking pool in which the stream was staked.
struct StreamLookup {
    // Slot 0
    address owner;
    // Slot 1
    uint256 poolId;
}

/// @notice A data structure to store a user's shares of tokens staked in a pool.
/// @param streamsCount The number of Sablier streams that the user has staked.
/// @param directAmountStaked The total amount of ERC20 tokens staked directly by the user, denoted in staking token's
/// decimals.
/// @param streamAmountStaked The total amount of ERC20 tokens staked through Sablier streams, denoted in staking
/// token's decimals.
struct UserShares {
    // Slot 0
    uint128 streamsCount;
    uint128 streamAmountStaked;
    // Slot 1
    uint128 directAmountStaked;
}

/// @notice A data structure to store a user's rewards and staking data for a given pool.
/// @param lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
/// @param rewards The amount of reward tokens available to be claimed by the user, denoted in reward token's decimals.
/// @param rewardsEarnedPerTokenScaled The amount of rewards earned per staking token (includes both direct staking and
/// through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
struct UserSnapshot {
    // Slot 0
    uint40 lastUpdateTime;
    uint128 rewards;
    // Slot 1
    uint256 rewardsEarnedPerTokenScaled;
}
