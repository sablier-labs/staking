// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * This file defines all structs used in this Sablier Staking contract. You will notice that some structs contain "slot"
 * annotations - they are used to indicate the storage layout of the struct. It is more gas efficient to group small
 * data types together so that they fit in a single 32-byte slot.
 */

/// @notice A data structure to store the campaign parameters.
/// @param admin The admin of the campaign. This may be different from the campaign creator.
/// @param rewardToken The address of the ERC20 token to used as staking rewards.
/// @param stakingToken The address of the ERC20 token that can be staked either directly or through Sablier stream.
/// @param wasCanceled Boolean indicating if the stream was canceled.
/// @param endTime The end time of the campaign, denoted in UNIX timestamp.
/// @param startTime The start time of the campaign, denoted in UNIX timestamp.
/// @param totalRewards The amount of total rewards to be distributed during the campaign's duration, denoted in reward
/// token's decimals.
struct Campaign {
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

/// @notice A data structure to store the total rewards snapshot data for each campaign.
/// @param lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
/// @param rewardsDistributedPerTokenScaled The amount of rewards distributed per staking token (includes both direct
/// staking and through Sablier streams), scaled by {Helpers.SCALE_FACTOR} to minimize precision loss.
struct GlobalSnapshot {
    // Slot 0
    uint40 lastUpdateTime;
    // Slot 1
    uint256 rewardsDistributedPerTokenScaled;
}

/// @notice A data structure to reverse lookup from a Lockup stream ID to the campaign ID and original stream owner.
/// @param campaignId The ID of the campaign in which the stream was staked.
/// @param owner The original owner of the stream.
struct StreamLookup {
    // Slot 0
    uint256 campaignId;
    // Slot 1
    address owner;
}

/// @notice A data structure to store a user's shares of tokens staked in a campaign.
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

/// @notice A data structure to store a user's rewards and staking data for a given campaign.
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
