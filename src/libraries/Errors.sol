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

    /// @notice Thrown when an unauthorized action is attempted on a canceled campaign.
    error SablierStakingState_CampaignCanceled(uint256 campaignId);

    /// @notice Thrown when an unauthorized action is attempted on a non-existent campaign.
    error SablierStakingState_CampaignDoesNotExist(uint256 campaignId);

    /// @notice Thrown when an unauthorized action is attempted on an inactive campaign.
    error SablierStakingState_CampaignNotActive(uint256 campaignId, uint40 startTime, uint40 endTime);

    /// @notice Thrown when the stream ID associated with the lockup contract is not staked in any campaign.
    error SablierStakingState_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when zero address is used as an input argument.
    error SablierStakingState_ZeroAddress();

    /*//////////////////////////////////////////////////////////////////////////
                                  SABLIER-STAKING
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when creating a campaign with admin as the zero address.
    error SablierStaking_AdminZeroAddress();

    /// @notice Thrown when unstaking an amount that exceeds the total staked amount.
    error SablierStaking_AmountExceedsStakedAmount(
        uint256 campaignId, uint256 amountUnstaking, uint256 totalAmountStaked
    );

    /// @notice Thrown when canceling a campaign when the caller is not the campaign admin.
    error SablierStaking_CallerNotCampaignAdmin(uint256 campaignId, address caller, address campaignAdmin);

    /// @notice Thrown when unstaking a Lockup stream when the caller is not the original stream owner.
    error SablierStaking_CallerNotStreamOwner(
        ISablierLockupNFT lockup, uint256 streamId, address caller, address streamOwner
    );

    /// @notice Thrown when cancelling a campaign that has already been started.
    error SablierStaking_CampaignAlreadyStarted(uint256 campaignId, uint40 startTime);

    /// @notice Thrown when staking into a campaign that has been ended.
    error SablierStaking_CampaignHasEnded(uint256 campaignId, uint40 endTime);

    /// @notice Thrown when an unauthorized action is attempted on a campaign that has not started yet.
    error SablierStaking_CampaignNotStarted(uint256 campaignId, uint40 startTime);

    /// @notice Thrown when staking a Lockup stream with depleted status.
    error SablierStaking_DepletedStream(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when creating a campaign with end time less than start time.
    error SablierStaking_EndTimeNotGreaterThanStartTime(uint40 startTime, uint40 endTime);

    /// @notice Thrown when the fee paid is less than the minimum fee.
    error SablierStaking_InsufficientFeePayment(uint256 feePaid, uint256 minFee);

    /// @notice Thrown when whitelisting a lockup contract that is already whitelisted.
    error SablierStaking_LockupAlreadyWhitelisted(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when staking a Lockup stream when the associated lockup contract is not whitelisted.
    error SablierStaking_LockupNotWhitelisted(ISablierLockupNFT lockup);

    /// @notice Thrown when whitelisting the zero address.
    error SablierStaking_LockupZeroAddress(uint256 index);

    /// @notice Thrown when the user has no rewards to claim.
    error SablierStaking_ZeroClaimableRewards(uint256 campaignId, address user);

    /// @notice Thrown when snapshotting rewards for a user when the user has no staked amount.
    error SablierStaking_NoStakedAmount(uint256 campaignId, address user);

    /// @notice Thrown when creating a campaign with zero reward amount.
    error SablierStaking_RewardAmountZero();

    /// @notice Thrown when creating a campaign with reward token as the zero address.
    error SablierStaking_RewardTokenZeroAddress();

    /// @notice Thrown when snapshotting rewards for a user when the last snapshot time exceeds the campaign end time.
    error SablierStaking_SnapshotNotAllowed(uint256 campaignId, address user, uint40 lastSnapshotTime);

    /// @notice Thrown when creating a campaign with staking token as the zero address.
    error SablierStaking_StakingTokenZeroAddress();

    /// @notice Thrown when staking into a campaign with zero amount.
    error SablierStaking_StakingZeroAmount(uint256 campaignId);

    /// @notice Thrown when creating a campaign with start time in the past.
    error SablierStaking_StartTimeInPast(uint40 startTime);

    /// @notice Thrown when an unauthorized action is attempted using a Lockup stream that is not staked in any
    /// campaign.
    error SablierStaking_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when staking a Lockup stream with an underlying token different from the allowed staking token.
    error SablierStaking_UnderlyingTokenDifferent(IERC20 underlyingToken, IERC20 stakingToken);

    /// @notice Thrown when unstaking zero amount from a campaign.
    error SablierStaking_UnstakingZeroAmount(uint256 campaignId);

    /// @notice Thrown when whitelisting a Lockup contract that has not enabled hook call with this contract.
    error SablierStaking_UnsupportedOnAllowedToHook(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when the zero address is used as an input argument.
    error SablierStaking_UserZeroAddress();

    /// @notice Thrown when withdraw is attempted on a Lockup stream that is staked in a campaign.
    error SablierStaking_WithdrawNotAllowed(uint256 campaignId, ISablierLockupNFT lockup, uint256 streamId);
}
