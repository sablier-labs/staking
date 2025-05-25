// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

/// @notice A struct to manage the campaign IDs.
/// @param canceledCampaign A campaign that has been canceled.
/// @param defaultCampaign The default campaign.
/// @param freshCampaign A campaign that has been created but not staked into.
/// @param nullCampaign A campaign ID that does not exist.
struct CampaignIds {
    uint256 canceledCampaign;
    uint256 defaultCampaign;
    uint256 freshCampaign;
    uint256 nullCampaign;
}

/// @notice A struct to manage the stream IDs.
/// @param defaultStakedStream A cancelable stream that will be staked into the default campaign.
/// @param defaultStakedStreamNonCancelable A non-cancelable stream that will be staked into the default campaign.
/// @param defaultStream A stream that will is not staked into the default campaign.
/// @param differentTokenStream A stream with a different token.
struct StreamIds {
    uint256 defaultStakedStream;
    uint256 defaultStakedStreamNonCancelable;
    uint256 defaultStream;
    uint256 differentTokenStream;
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

/// @notice A struct to manage variables during tests preventing stack too deep errors.
struct Vars {
    uint40 actualLastUpdateTime;
    uint256 actualRewardsPerTokenScaled;
    uint256 expectedRewardsPerTokenScaled;
    uint128 expectedUserRewards;
}
