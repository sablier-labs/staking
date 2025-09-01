// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * This file defines all structs used in this Sablier Staking contract. You will notice that some structs contain "slot"
 * annotations - they are used to indicate the storage layout of the struct. It is more gas efficient to group small
 * data types together so that they fit in a single 32-byte slot.
 */

/// @notice A data structure to store the pool data.
/// @param admin The admin of the staking pool. This may be different from the pool creator.
/// @param endTime The end time of the rewards period, denoted in UNIX timestamp.
/// @param startTime The start time of the rewards period, denoted in UNIX timestamp.
/// @param rewardToken The address of the ERC20 token to used as staking rewards.
/// @param snapshotTime The Unix timestamp used to calculate the global amount of rewards distributed per staking token.
/// @param stakingToken The address of the ERC20 token that can be staked either directly or through Sablier stream.
/// @param rewardAmount The amount of rewards to be distributed between the start and end times, denoted in reward
/// token's decimals.
/// @param totalStakedAmount The total amount of tokens staked in a pool (both direct staking and through Sablier
/// streams), denoted in staking token's decimals.
/// @param snapshotRptDistributedScaled The global amount of rewards distributed per staking token at snapshot time,
/// includes both direct staking and through Sablier Lockup streams, scaled by {Helpers.SCALE_FACTOR} to minimize
/// precision loss.
struct Pool {
    // Slot 0
    address admin;
    uint40 endTime;
    uint40 startTime;
    // Slot 1
    IERC20 rewardToken;
    uint40 snapshotTime;
    // Slot 2
    IERC20 stakingToken;
    // Slot 3
    uint128 rewardAmount;
    uint128 totalStakedAmount;
    // Slot 4
    uint256 snapshotRptDistributedScaled;
}

/// @notice Enum to represent the different statuses of a staking pool.
/// @custom:value0 SCHEDULED The staking period is scheduled to start in the future.
/// @custom:value1 ACTIVE The staking period is active and rewards are being distributed to stakers.
/// @custom:value2 COMPLETED The staking period has ended and rewards are no longer being distributed.
enum Status {
    SCHEDULED,
    ACTIVE,
    ENDED
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

/// @notice A data structure to store the user's staked amount in a pool and the reward data.
/// @param directAmountStaked The total amount of ERC20 tokens staked directly by the user, denoted in staking token's
/// decimals.
/// @param streamAmountStaked The total amount of ERC20 tokens staked through Sablier streams, denoted in staking
/// token's decimals.
/// @param snapshotRewards The amount of reward tokens available to be claimed during previous user's snapshot, denoted
/// in reward token's decimals.
/// @param snapshotRptEarnedScaled The amount of rewards earned per staking token (includes both direct staking and
/// through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
struct UserAccount {
    // Slot 0
    uint128 directAmountStaked;
    uint128 streamAmountStaked;
    // Slot 1
    uint128 snapshotRewards;
    // Slot 2
    uint256 snapshotRptEarnedScaled;
}
