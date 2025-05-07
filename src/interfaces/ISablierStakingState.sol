// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { GlobalSnapshot, UserSnapshot } from "../types/DataTypes.sol";
import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";

/// @title ISablierStakingState
/// @notice See the documentation in {ISablierStakingState}.
interface ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the admin of the given campaign ID.
    /// @dev Reverts if `campaignId` references a null stream.
    function getAdmin(uint256 campaignId) external view returns (address);

    /// @notice Returns the end time of the given campaign ID, denoted in UNIX timestamp.
    /// @dev Reverts if `campaignId` references a null stream.
    function getEndTime(uint256 campaignId) external view returns (uint40);

    /// @notice Returns the reward token of the given campaign ID, denoted in token's decimals.
    /// @dev Reverts if `campaignId` references a null stream.
    function getRewardToken(uint256 campaignId) external view returns (IERC20);

    /// @notice Returns the staking token of the given campaign ID.
    /// @dev Reverts if `campaignId` references a null stream.
    function getStakingToken(uint256 campaignId) external view returns (IERC20);

    /// @notice Returns the start time of the given campaign ID, denoted in UNIX timestamp.
    /// @dev Reverts if `campaignId` references a null stream.
    function getStartTime(uint256 campaignId) external view returns (uint40);

    /// @notice Returns the total rewards of the given campaign ID, denoted in token's decimals.
    /// @dev Reverts if `campaignId` references a null stream.
    function getTotalRewards(uint256 campaignId) external view returns (uint256);

    /// @notice Retrieves the global snapshot data for the given campaign ID.
    /// @dev Reverts if `campaignId` references a null stream.
    /// @param campaignId The campaign ID for the query.
    /// @return snapshot See the documentation for GlobalSnapshot in {DataTypes}.
    function globalSnapshot(uint256 campaignId) external view returns (GlobalSnapshot memory snapshot);

    /// @notice Returns true if the lockup contract is whitelisted to stake.
    function isLockupWhitelisted(ISablierLockupNFT lockup) external view returns (bool);

    /// @notice Returns the role authorized to whitelist the lockup contracts for staking into the campaign.
    function LOCKUP_WHITELIST_ROLE() external view returns (bytes32);

    /// @notice Counter for the next campaign ID, used in launching new campaigns.
    function nextCampaignId() external view returns (uint256);

    /// @notice Retrieves the details of a stream staked.
    /// @dev Reverts if the stream is not staked in any campaign.
    /// @param lockup The lockup contract for the query.
    /// @param streamId The stream ID for the query.
    /// @return campaignId The campaign ID of the campaign in which the stream is staked.
    /// @return owner The original owner of the stream.
    function stakedStream(
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        view
        returns (uint256 campaignId, address owner);

    /// @notice Retrieves the snapshot data of a user for the given campaign ID.
    /// @dev Reverts if `campaignId` references a null stream.
    /// @param campaignId The campaign ID for the query.
    /// @param user The user address for the query.
    /// @return snapshot See the documentation for UserSnapshot in {DataTypes}.
    function userSnapshot(uint256 campaignId, address user) external view returns (UserSnapshot memory snapshot);

    /// @notice Returns true if the given campaign ID was canceled.
    /// @dev Reverts if `campaignId` references a null stream.
    function wasCanceled(uint256 campaignId) external view returns (bool);
}
