// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /// @notice Thrown when amount parameter is zero.
    error SablierStakingCampaign_AmountZero();

    error SablierStakingCampaign_ExceedStakedAmount(
        uint256 campaignId, uint256 amountToUnstake, uint256 totalStakedAmount
    );

    /// @notice Thrown when the caller is not the lockup contract.
    error SablierStakingCampaign_UnauthorizedCaller(address caller, uint256 streamId);

    /// @notice Thrown if provided lockup address is not a contract.
    error SablierStakingCampaign_LockupAddressNotContract(address lockupAddress);

    /// @notice Thrown when campaign is created with zero address as admin.
    error SablierStakingCampaign_ZeroAddress();

    /// @notice Thrown when campaign is created with zero total reward amount.
    error SablierStakingCampaign_ZeroRewardAmount();

    /// @notice Thrown when user tries to stake zero amount of tokens.
    error SablierStakingCampaign_ZeroStakingAmount();

    /// @notice Thrown when campaign start time exceeds end time.
    error SablierStakingCampaign_StartTimeExceedsEndTime(uint40 startTime, uint40 endTime);

    /// @notice Thrown when campaign start time is in the past.
    error SablierStakingCampaign_StartTimeInPast(uint40 startTime);

    /// @notice Thrown when campaign does not exist.
    error SablierStakingCampaign_CampaignDoesNotExist(uint256 campaignId);

    /// @notice Thrown when the lockup token is not authorized for the campaign.
    error SablierStakingCampaign_LockupTokenNotAllowed(IERC20 lockupUnderlyingToken, IERC20 stakingERC20Token);

    /// @notice Thrown when user is staking in a campaign that has ended.
    error SablierStakingCampaign_CampaignHasEnded(uint40 endTime);

    /// @notice Thrown when user is trying to stake a Lockup stream that is already staked in another campaign.
    error SablierStakingCampaign_StreamAlreadyStaked(uint256 streamId, uint256 campaignId);

    /// @notice Thrown when withdraw hook call is made on a stream that is staked in a campaign.
    error SablierStakingCampaign_WithdrawDisabled(uint256 streamId);

    /// @notice Thrown when user has zero ERC20 token staked in the campaign.
    error SablierStakingCampaign_ERC20StakingAmountZero(uint256 campaignId, address caller);

    /// @notice Thrown when the stream ID is not staked in any campaign.
    error SablierStakingCampaign_StreamNotStaked(address lockupAddress, uint256 streamId, address caller);

    error SablierStakingCampaign_CallerNotStreamOwner(uint256 streamId, address caller, address streamOwner);

    error SablierStakingCampaign_CampaignHasStarted(uint256 campaignId, uint40 startTime);
}
