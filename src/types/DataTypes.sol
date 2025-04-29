// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";

/// @notice The struct that represents a rewards campaign.
/// @param admin The address of the admin that created the campaign.
/// @param stakingToken The address of the ERC20 token that can be staked either directly or through Sablier stream
/// to earn rewards.
/// @param startTime The start time of the campaign, denoted in UNIX timestamp.
/// @param endTime The end time of the campaign, denoted in UNIX timestamp.
/// @param rewardToken The address of the ERC20 token that is used to reward stakers.
/// @param totalRewards The amount of reward tokens to be distributed during the campaign's duration, denoted in
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

struct GlobalRewards {
    // Slot 0
    uint128 rewardsDistributedPerToken;
    uint128 totalStakedTokens;
    // Slot 1
    uint40 lastUpdateTIme;
}

struct UserRewards {
    // Slot 0
    uint128 rewardsDistributedPerToken;
    uint128 totalStakedTokens;
    // Slot 1
    uint128 stakedERC20Amount;
    uint32 stakedStreamsCount;
    // Slot 2
    uint128 rewards;
}

struct StakedStream {
    // Slot 0
    uint256 campaignId;
    // Slot 1
    address owner;
}

struct SablierLockupNFT {
    ISablierLockupNFT lockupAddress;
    uint256 streamId;
}
