// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IRoleAdminable } from "@sablier/evm-utils/src/interfaces/IRoleAdminable.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";
import { ISablierStakingState } from "./ISablierStakingState.sol";

/// @title ISablierStaking
/// @notice Singleton contract to launch staking campaigns allowing staking of both ERC20 tokens and Sablier Lockup
/// NFTs.
///
/// Features:
///  - Create staking campaigns by specifying the staking token, reward token, reward duration and reward amount.
///  - Users can stake ERC20 tokens into the campaign to earn rewards.
///  - Users can stake their Sablier Lockup streams, as long as the underlying token matches the staking token, to earn
/// rewards based on the total amount of underlying token in the stream.
///  - Users can stake multiple Lockup streams, or both Lockup streams and ERC20 tokens simultaneously.
///  - Supports multiple versions of Lockup contracts, requires whitelisting by the protocol admin.
///  - Users can unstake their positions, with the ability to stake and unstake multiple times.
///  - Each Lockup stream can only be staked in one campaign at a time.
///  - Cancelling a staked stream would adjust the stakers total amount staked.
///  - Withdrawing from a staked stream would revert.
///  - Campaign admin can cancel the campaign until the start time.
interface ISablierStaking is ISablierStakingState, IRoleAdminable, IERC721Receiver, ISablierLockupRecipient {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a campaign is created before the start time.
    event CancelStakingCampaign(uint256 indexed campaignId);

    /// @notice Emitted when rewards are claimed.
    event ClaimRewards(uint256 indexed campaignId, address indexed user, uint256 amountClaimed);

    /// @notice Emitted when a new staking campaign is created.
    event CreateStakingCampaign(
        uint256 indexed campaignId,
        address indexed admin,
        IERC20 indexed stakingToken,
        IERC20 rewardToken,
        uint40 startTime,
        uint40 endTime,
        uint128 totalRewards
    );

    /// @notice Emitted when a Lockup contract is whitelisted.
    event LockupWhitelisted(ISablierLockupNFT indexed lockup);

    /// @notice Emitted when the rewards snapshot is taken.
    event SnapshotRewards(
        uint256 indexed campaignId,
        address indexed user,
        uint128 rewards,
        uint128 rewardsDistributedPerToken,
        uint128 totalStakedTokens
    );

    /// @notice Emitted when a user stakes ERC20 tokens in a campaign.
    event StakeERC20Token(uint256 indexed campaignId, address indexed user, uint256 amountStaked);

    /// @notice Emitted when a user stakes a Lockup stream in a campaign.
    event StakeLockupNFT(
        uint256 indexed campaignId,
        address indexed user,
        ISablierLockupNFT indexed lockup,
        uint256 streamId,
        uint128 underlyingTokenAmount
    );

    /// @notice Emitted when a user unstakes ERC20 tokens from a campaign.
    event UnstakeERC20Token(uint256 indexed campaignId, address indexed user, uint256 amountUnstaked);

    /// @notice Emitted when a user unstakes a Lockup stream from a campaign.
    event UnstakeLockupNFT(
        uint256 indexed campaignId, address indexed user, ISablierLockupNFT indexed lockup, uint256 streamId
    );

    /*//////////////////////////////////////////////////////////////////////////
                                READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount of reward ERC20 tokens that total staked ERC20 tokens are earning every second.
    /// Returns 0 if total staked tokens are 0.
    /// @dev Reverts if `campaignId` references a null stream, or is inactive (including canceled).
    function rewardRate(uint256 campaignId) external view returns (uint128);

    /// @notice Returns the amount of reward ERC20 token that each staked ERC20 token is earning every second. Returns 0
    /// if total staked tokens are 0.
    /// @dev Reverts if `campaignId` references a null stream or is inactive (including canceled).
    function rewardRatePerTokenStaked(uint256 campaignId) external view returns (uint128);

    /// @notice Returns the user's stake in the specified campaign.
    ///
    /// @dev Reverts if `campaignId` references a null stream.
    ///
    /// @param campaignId The campaign ID for the query.
    /// @param user The address of the user for the query.
    ///
    /// @return amountStakedDirectly The total amount of ERC20 tokens staked directly by the user, denoted in staking
    /// token's decimals.
    /// @return amountStakedWithStreams The total amount of ERC20 tokens staked through Lockup streams, denoted in
    /// staking token's decimals.
    /// @return totalStreams The total number of Lockup streams staked by the user.
    function totalStakedByUser(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (uint128 amountStakedDirectly, uint128 amountStakedWithStreams, uint128 totalStreams);

    /*//////////////////////////////////////////////////////////////////////////
                              STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Cancels the staking campaign and refunds rewards amount to the campaign admin.
    /// @dev Emits a {Transfer} and {CancelStakingCampaign} events.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null stream or a canceled campaign.
    ///  - `msg.sender` must be the campaign admin.
    ///  - The campaign's start time must be in the future.
    ///
    /// @param campaignId The campaign ID to cancel.
    function cancelStakingCampaign(uint256 campaignId) external returns (uint128 amountRefunded);

    /// @notice Claims the rewards earned by `msg.sender` in the specified campaign.
    /// @dev Emits a {Transfer} and {ClaimRewards} events.
    ///
    /// Notes:
    /// - Updates global rewards and user rewards data.
    /// - Sets the last time update for user.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null stream or a canceled campaign.
    ///  - Claimable rewards must be greater than 0.
    ///
    /// @param campaignId The campaign ID to claim rewards from.
    /// @return rewards The amount of rewards claimed, denoted in reward token's decimals.
    function claimRewards(uint256 campaignId) external returns (uint128 rewards);

    /// @notice Creates a new staking campaign and transfer the total reward amount from `msg.sender` to this contract.
    /// @dev Emits a {Transfer} and {CreateStakingCampaign} events.
    ///
    /// Requirements:
    ///  - `admin` must not be the zero address.
    ///  - `startTime` must be greater than or equal to the `block.timestamp`.
    ///  - `endTime` must be greater than `startTime`.
    ///  - `stakingToken` must not be the zero address.
    ///  - `rewardToken` must not be the zero address.
    ///  - `rewardsAmount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the `rewardsAmount` of reward ERC20 token.
    ///
    /// @param admin The admin of the campaign with the ability to cancel it until the start time.
    /// @param stakingToken The ERC20 token permitted for staking either directly or through Lockup streams.
    /// @param startTime The start time of the campaign, denoted in UNIX timestamp.
    /// @param endTime The end time of the campaign, denoted in UNIX timestamp.
    /// @param rewardToken The ERC20 token that will be distributed as rewards.
    /// @param totalRewards The amount of reward tokens to distribute, denoted in reward token's decimals.
    /// @return campaignId The ID of the newly created campaign.
    function createStakingCampaign(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 totalRewards
    )
        external
        returns (uint256 campaignId);

    /// @notice Handles the hook call from the Lockup contract when a staked stream is canceled.
    /// @dev This function permits cancelling a staked stream and adjusts the total staked tokens in the campaign
    /// accordingly.
    ///
    /// Notes:
    /// - Updates global rewards and user rewards data.
    ///
    /// Requirements:
    /// - `msg.sender` must be a whitelisted Lockup contract.
    ///  - `streamId` must be staked in a campaign.
    ///
    /// @param streamId The ID of the stream on which cancel is called.
    /// @param sender The address that initiated the cancellation.
    /// @param senderAmount The amount of tokens refunded to the sender.
    /// @param recipientAmount The amount of the tokens belonging to the recipient.
    /// @return The required selector.
    function onSablierLockupCancel(
        uint256 streamId,
        address sender,
        uint128 senderAmount,
        uint128 recipientAmount
    )
        external
        returns (bytes4);

    /// @notice Handles the hook call from the Lockup contract when withdraw is called on a staked stream.
    /// @dev This function reverts and does not permit withdrawing from a staked stream.
    ///
    /// @param streamId The ID of the stream on which withdraw is called.
    /// @param caller The address that initiated the withdrawal.
    /// @param recipient The recipient of the stream which is this contract.
    /// @param amount The amount of tokens to withdraw.
    /// @return The required selector.
    function onSablierLockupWithdraw(
        uint256 streamId,
        address caller,
        address recipient,
        uint128 amount
    )
        external
        view
        returns (bytes4);

    /// @notice Snapshot global rewards and user rewards data for the specified campaign and user.
    /// @dev Emits a {SnapshotRewards} event.
    ///
    /// Notes:
    ///  - If user has no stakes, it only snapshots the global rewards data.
    ///
    /// @param campaignId The campaign ID to snapshot rewards data for.
    /// @param user The address of the user to snapshot rewards data for.
    function snapshotRewards(uint256 campaignId, address user) external;

    /// @notice Stakes ERC20 staking token in the specified campaign.
    /// @dev Emits a {Transfer} and {StakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the campaign start
    /// time.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null stream or a canceled campaign.
    ///  - Campaign end time must be in the future.
    ///  - `amount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the ERC20 token.
    ///
    /// @param campaignId The campaign ID to stake the ERC20 token in.
    function stakeERC20Token(uint256 campaignId, uint128 amount) external;

    /// @notice Stakes a Lockup stream in the specified campaign.
    /// @dev Emits a {Transfer} and {StakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the campaign start
    /// time.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null stream or a canceled campaign.
    ///  - `lockup` must be a whitelisted Lockup contract.
    ///  - Campaign end time must be in the future.
    ///  - Stream's underlying token must be same as the campaign's staking token.
    ///  - The amount in stream must not be zero, i.e. it must not be depleted.
    ///  - `msg.sender` must have approved this contract to spend the stream ID.
    ///
    /// @param campaignId The campaign ID to stake the Lockup stream in.
    /// @param lockup The Lockup contract associated with the stream ID.
    /// @param streamId The ID of the stream to stake.
    function stakeLockupNFT(uint256 campaignId, ISablierLockupNFT lockup, uint256 streamId) external;

    /// @notice Unstakes the amount specified of the staking token from the specified campaign.
    /// @dev Emits a {Transfer} and {UnstakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    /// - `campaignId` must not reference a null stream.
    /// - `amount` must be greater than 0 and must not exceed the user's staked ERC20 amount in the campaign.
    ///
    /// @param campaignId The campaign ID to unstake the ERC20 token from.
    /// @param amount The amount of ERC20 tokens to unstake.
    function unstakeERC20Token(uint256 campaignId, uint128 amount) external;

    /// @notice Unstakes the Lockup stream from the specified campaign.
    /// @dev Emits a {Transfer} and {UnstakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    /// - The stream ID associated with `lockup` must be staked in a campaign.
    /// - `msg.sender` must be the original owner of the stream stored in {StakedStream} struct.
    ///
    /// @param lockup The Lockup contract associated with the stream ID.
    /// @param streamId The ID of the stream to unstake.
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external;

    /// @notice Whitelist a list of Lockup contracts enabling their stream IDs to be staked in any campaign.
    /// @dev Emits {LockupWhitelisted} event for each Lockup contract.
    ///
    /// Notes:
    ///  - It does nothing if the array is empty.
    ///
    /// Requirements:
    ///  - Each lockup contract must not already be whitelisted.
    ///  - Each lockup contract must return `true` when `isAllowedToHook` is called with this contract's address.
    ///  - `msg.sender` must either be the protocol admin or have the `LOCKUP_WHITELIST_ROLE`.
    ///
    /// @param lockups The address of the Lockup contract to whitelist.
    function whitelistLockups(ISablierLockupNFT[] calldata lockups) external;
}
