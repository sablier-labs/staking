// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";

/// @title ISablierStakingState
/// @notice  Contract with state variables (storage and constants) for the {SablierStaking} contract, respective getters
/// and helpful modifiers.
interface ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the admin of the given campaign ID.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getAdmin(uint256 campaignId) external view returns (address);

    /// @notice Returns the end time of the given campaign ID, denoted in UNIX timestamp.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getEndTime(uint256 campaignId) external view returns (uint40);

    /// @notice Returns the reward token of the given campaign ID, denoted in token's decimals.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getRewardToken(uint256 campaignId) external view returns (IERC20);

    /// @notice Returns the staking token of the given campaign ID.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getStakingToken(uint256 campaignId) external view returns (IERC20);

    /// @notice Returns the start time of the given campaign ID, denoted in UNIX timestamp.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getStartTime(uint256 campaignId) external view returns (uint40);

    /// @notice Returns the total rewards of the given campaign ID, denoted in token's decimals.
    /// @dev Reverts if `campaignId` references a null campaign.
    function getTotalRewards(uint256 campaignId) external view returns (uint128);

    /// @notice Retrieves the global rewards snapshot for the given campaign ID.
    /// @dev Reverts if `campaignId` references a null campaign.
    /// @param campaignId The campaign ID for the query.
    /// @return lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
    /// @return rewardsDistributedPerTokenScaled The amount of rewards distributed per staking token, scaled by
    /// {Helpers.SCALE_FACTOR} to minimize precision loss.
    function globalSnapshot(uint256 campaignId)
        external
        view
        returns (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled);

    /// @notice Returns true if the lockup contract is whitelisted to stake.
    /// @dev Reverts if `lockup` is the zero address.
    function isLockupWhitelisted(ISablierLockupNFT lockup) external view returns (bool);

    /// @notice Returns the role authorized to whitelist the lockup contracts for staking into the campaign.
    function LOCKUP_WHITELIST_ROLE() external view returns (bytes32);

    /// @notice Counter for the next campaign ID, used in launching new campaigns.
    function nextCampaignId() external view returns (uint256);

    /// @notice Lookup from a Lockup stream ID to the campaign ID and original stream owner.
    /// @dev Reverts if the lockup is the zero address or the stream ID is not staked in any campaign.
    /// @param lockup The lockup contract for the query.
    /// @param streamId The stream ID for the query.
    /// @return campaignId The campaign ID of the campaign in which the stream is staked.
    /// @return owner The original owner of the stream.
    function streamLookup(
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        view
        returns (uint256 campaignId, address owner);

    /// @notice Returns the total amount of tokens staked (both direct staking and through Sablier streams), denoted in
    /// staking token's decimals.
    /// @dev Reverts if `campaignId` references a null campaign.
    function totalAmountStaked(uint256 campaignId) external view returns (uint128);

    /// @notice Returns the total amount of tokens staked by a user (both direct staking and through Sablier streams) in
    /// the given campaign, denoted in staking token's decimals.
    /// @dev Reverts if `campaignId` references a null campaign or `user` is the zero address.
    function totalAmountStakedByUser(uint256 campaignId, address user) external view returns (uint128);

    /// @notice Returns the user's shares of tokens staked in a campaign.
    /// @dev Reverts if `campaignId` references a null campaign or `user` is the zero address.
    /// @param campaignId The campaign ID for the query.
    /// @param user The user address for the query.
    /// @return streamsCount The number of Sablier streams that the user has staked.
    /// @return streamAmountStaked The total amount of ERC20 tokens staked through Sablier streams, denoted in staking
    /// token's decimals.
    /// @return directAmountStaked The total amount of ERC20 tokens staked directly by the user, denoted in staking
    /// token's decimals.
    function userShares(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (uint128 streamsCount, uint128 streamAmountStaked, uint128 directAmountStaked);

    /// @notice Retrieves the rewards snapshot of a user for the given campaign ID.
    /// @dev Reverts if `campaignId` references a null campaign or `user` is the zero address.
    /// @param campaignId The campaign ID for the query.
    /// @param user The user address for the query.
    /// @return lastUpdateTime The last time this snapshot was updated, denoted in UNIX timestamp.
    /// @return rewardsEarnedPerTokenScaled The amount of rewards earned per staking token, scaled by
    /// {Helpers.SCALE_FACTOR} to minimize precision loss.
    /// @return rewards The amount of rewards earned by the user until last snapshot, denoted in token's decimals.
    function userSnapshot(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (uint40 lastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards);

    /// @notice Returns true if the given campaign ID was canceled.
    /// @dev Reverts if `campaignId` references a null campaign.
    function wasCanceled(uint256 campaignId) external view returns (bool);
}
