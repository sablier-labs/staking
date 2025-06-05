// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                               SABLIER-STAKING-STATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an action is attempted on a canceled campaign.
    error SablierStakingState_CampaignCanceled(uint256 campaignId);

    /// @notice Thrown when an action is attempted on a non-existent campaign.
    error SablierStakingState_CampaignDoesNotExist(uint256 campaignId);

    /// @notice Thrown when an action is attempted on an inactive campaign.
    error SablierStakingState_CampaignNotActive(uint256 campaignId, uint40 startTime, uint40 endTime);

    /// @notice Thrown when the lockup contract is not whitelisted.
    error SablierStakingState_LockupNotWhitelisted(ISablierLockupNFT lockup);

    /// @notice Thrown when the stream ID associated with Lockup contract is not staked in any campaign.
    error SablierStakingState_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when the input argument is the zero address.
    error SablierStakingState_ZeroAddress();

    /*//////////////////////////////////////////////////////////////////////////
                                  SABLIER-STAKING
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to create a campaign with the zero address as admin.
    error SablierStaking_AdminZeroAddress();

    /// @notice Thrown when the unstaking amount exceeds the ERC20 staked amount.
    error SablierStaking_AmountExceedsStakedAmount(
        uint256 campaignId, uint256 amountUnstaking, uint256 totalAmountStaked
    );

    /// @notice Thrown when the caller is not the campaign admin.
    error SablierStaking_CallerNotCampaignAdmin(uint256 campaignId, address caller, address campaignAdmin);

    /// @notice Thrown when the caller is not the original owner of the stream.
    error SablierStaking_CallerNotStreamOwner(
        ISablierLockupNFT lockup, uint256 streamId, address caller, address streamOwner
    );

    /// @notice Thrown when trying to cancel a campaign that has already started.
    error SablierStaking_CampaignAlreadyStarted(uint256 campaignId, uint40 startTime);

    /// @notice Thrown when user is staking in a campaign that has ended.
    error SablierStaking_CampaignHasEnded(uint256 campaignId, uint40 endTime);

    /// @notice Thrown when campaign has not started yet.
    error SablierStaking_CampaignNotStarted(uint256 campaignId, uint40 startTime);

    /// @notice Thrown when staking a depleted stream.
    error SablierStaking_DepletedStream(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when trying to create a campaign with end time not greater than start time.
    error SablierStaking_EndTimeNotGreaterThanStartTime(uint40 startTime, uint40 endTime);

    /// @notice Thrown when the lockup contract at the given index is already whitelisted.
    error SablierStaking_LockupAlreadyWhitelisted(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when staking a stream when the associated lockup contract is not whitelisted.
    error SablierStaking_LockupNotWhitelisted(ISablierLockupNFT lockup);

    /// @notice Thrown when the lockup contract at the given index is the zero address.
    error SablierStaking_LockupZeroAddress(uint256 index);

    /// @notice Thrown when the user has no rewards to claim.
    error SablierStaking_ZeroClaimableRewards(uint256 campaignId, address user);

    /// @notice Thrown when the user has no staked amount.
    error SablierStaking_NoStakedAmount(uint256 campaignId, address user);

    /// @notice Thrown when trying to create a campaign with reward amount as zero.
    error SablierStaking_RewardAmountZero();

    /// @notice Thrown when trying to create a campaign with reward token as the zero address.
    error SablierStaking_RewardTokenZeroAddress();

    /// @notice Thrown when trying to create a campaign with staking token as the zero address.
    error SablierStaking_StakingTokenZeroAddress();

    /// @notice Thrown when trying to stake a zero amount.
    error SablierStaking_StakingZeroAmount();

    /// @notice Thrown when trying to create a campaign with start time in the past.
    error SablierStaking_StartTimeInPast(uint40 startTime);

    /// @notice Thrown when a stream is not staked in any campaign.
    error SablierStaking_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when a function is called by an unauthorized caller.
    error SablierStaking_UnauthorizedCaller();

    /// @notice Thrown when staking a Lockup stream with a different underlying token.
    error SablierStaking_UnderlyingTokenDifferent(IERC20 underlyingToken, IERC20 stakingToken);

    /// @notice Thrown when unstaking a zero amount.
    error SablierStaking_UnstakingZeroAmount();

    /// @notice Thrown when lockup contract at the given index has not allowed this contract to hook.
    error SablierStaking_UnsupportedOnAllowedToHook(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when trying to withdraw from a staked stream.
    error SablierStaking_WithdrawNotAllowed(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when the input argument is the zero address.
    error SablierStaking_ZeroAddress();
}
