// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * This file defines all structs used in this Sablier Staking contract. You will notice that some structs contain "slot"
 * annotations - they are used to indicate the storage layout of the struct. It is more gas efficient to group small
 * data types together so that they fit in a single 32-byte slot.
 */

/// @notice An in-memory struct to group user staked amounts.
/// @param streamsCount The number of Sablier streams that the user has staked.
/// @param directAmountStaked The total amount of ERC20 tokens staked directly by the user, denoted in staking token's
/// decimals.
/// @param streamAmountStaked The total amount of ERC20 tokens staked through Sablier streams, denoted in staking
/// token's decimals.
/// @param totalAmountStaked The combined amount of ERC20 tokens staked by the user (includes both direct staking
/// and through Sablier streams), denoted in staking token's decimals.
struct Amounts {
    uint128 streamsCount;
    uint128 directAmountStaked;
    uint128 streamAmountStaked;
    uint128 totalAmountStaked;
}

/// @notice A data structure to store the total rewards snapshot data for each campaign.
/// @param rewardsDistributedPerTokenScaled The amount of rewards distributed per staking token (includes both direct
/// staking and through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
/// @param totalAmountStaked The total amount of staking tokens staked (both direct staking and through Sablier
/// streams), denoted in staking token's decimals.
/// @param lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
struct GlobalSnapshot {
    // Slot 0
    uint256 rewardsDistributedPerTokenScaled;
    uint128 totalAmountStaked;
    // Slot 1
    uint40 lastUpdateTime;
}

/// @notice A data structure to store the campaign parameters.
/// @param admin The admin of the campaign. This may be different from the campaign creator.
/// @param rewardToken The address of the ERC20 token to used as staking rewards.
/// @param stakingToken The address of the ERC20 token that can be staked either directly or through Sablier stream.
/// @param wasCanceled Boolean indicating if the stream was canceled.
/// @param endTime The end time of the campaign, denoted in UNIX timestamp.
/// @param startTime The start time of the campaign, denoted in UNIX timestamp.
/// @param totalRewards The amount of total rewards to be distributed during the campaign's duration, denoted in reward
/// token's decimals.
struct StakingCampaign {
    // Slot 0
    address admin;
    // Slot 1
    IERC20 rewardToken;
    // Slot 2
    IERC20 stakingToken;
    // Slot 3
    bool wasCanceled;
    uint40 endTime;
    uint40 startTime;
    uint128 totalRewards;
}

/// @notice A data structure to reverse lookup from a Lockup stream ID to the campaign ID and original stream owner.
/// @param campaignId The ID of the campaign in which the stream was staked.
/// @param owner The original owner of the stream.
struct StakedStream {
    // Slot 0
    uint256 campaignId;
    // Slot 1
    address owner;
}

/// @notice A data structure to store a user's rewards and staking data for a given campaign.
/// @param rewards The amount of reward tokens available to be claimed by the user, denoted in reward token's decimals.
/// @param rewardsEarnedPerTokenScaled The amount of rewards earned per staking token (includes both direct staking and
/// through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
/// @param directAmountStaked The amount of staking tokens staked directly, denoted in staking token's decimals.
/// @param totalAmountStaked The total amount of staking tokens staked (both direct staking and through Sablier
/// streams), denoted in staking token's decimals.
/// @param streamsCount The number of Sablier streams staked by the user.
/// @param lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
struct UserSnapshot {
    // Slot 0
    uint128 rewards;
    uint256 rewardsEarnedPerTokenScaled;
    // Slot 1
    uint128 directAmountStaked;
    uint128 totalAmountStaked;
    // Slot 2
    uint32 streamsCount;
    uint40 lastUpdateTime;
}
