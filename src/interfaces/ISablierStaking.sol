// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IComptrollerManager } from "@sablier/evm-utils/src/interfaces/IComptrollerManager.sol";

import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";
import { ISablierStakingState } from "./ISablierStakingState.sol";

/// @title ISablierStaking
/// @notice Creates and manages staking campaigns allowing staking of both ERC20 tokens and Sablier Lockup NFTs.
interface ISablierStaking is
    IComptrollerManager, // 0 inherited components
    IERC165, // 0 inherited components
    IERC721Receiver, // 0 inherited components
    ISablierStakingState // 0 inherited components
{
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a campaign is created before the start time.
    event CancelCampaign(uint256 indexed campaignId);

    /// @notice Emitted when rewards are claimed.
    event ClaimRewards(uint256 indexed campaignId, address indexed user, uint256 amountClaimed);

    /// @notice Emitted when a new staking campaign is created.
    event CreateCampaign(
        uint256 indexed campaignId,
        address indexed admin,
        IERC20 indexed stakingToken,
        IERC20 rewardToken,
        uint40 startTime,
        uint40 endTime,
        uint128 totalRewards
    );

    /// @notice Emitted when a Lockup contract is whitelisted.
    event LockupWhitelisted(address indexed comptroller, ISablierLockupNFT indexed lockup);

    /// @notice Emitted when the rewards snapshot is taken.
    event SnapshotRewards(
        uint256 indexed campaignId,
        uint40 lastUpdateTime,
        uint256 rewardsDistributedPerTokenScaled,
        address indexed user,
        uint128 userRewards
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

    /// @notice Returns the amount of reward ERC20 tokens available to claim by the user.
    /// @dev Reverts if `campaignId` references a null campaign or a canceled campaign, or if `user` is the zero
    /// address.
    function getClaimableRewards(uint256 campaignId, address user) external view returns (uint128);

    /// @notice Reverts on the hook call from the Lockup contract when a withdraw is called on a staked stream
    /// @dev This function reverts and does not permit withdrawing from a staked stream
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `streamId` must be staked in a campaign.
    ///
    /// @param streamId The ID of the stream on which withdraw is called.
    /// @param caller The original `msg.sender` address that triggered the withdrawal.
    /// @param to The address receiving the withdrawn tokens.
    /// @param amount The amount of tokens withdrawn, denoted in units of the token's decimals.
    ///
    /// @return selector The selector of this function needed to validate the hook.
    function onSablierLockupWithdraw(
        uint256 streamId,
        address caller,
        address to,
        uint128 amount
    )
        external
        view
        returns (bytes4 selector);

    /// @notice Returns the amount of reward ERC20 tokens that total staked ERC20 tokens are earning every second.
    /// Returns 0 if total staked tokens are 0.
    /// @dev Reverts if `campaignId` references a null campaign, or is inactive (including canceled).
    function rewardRate(uint256 campaignId) external view returns (uint128);

    /// @notice Returns the amount of reward ERC20 token that each staked ERC20 token is earning every second. Returns 0
    /// if total staked tokens are 0.
    /// @dev Reverts if `campaignId` references a null campaign or is inactive (including canceled).
    function rewardRatePerTokenStaked(uint256 campaignId) external view returns (uint128);

    /// @notice Calculates rewards distributed per ERC20 token since the last snapshot.
    /// @dev Returns 0 if the total staked tokens are 0 or the last time update is greater than or equal to the campaign
    /// end time.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  -  The campaign start time must not be in the future.
    function rewardsPerTokenSinceLastSnapshot(uint256 campaignId) external view returns (uint128);

    /// @notice Calculates rewards distributed since the last snapshot.
    /// @dev Returns 0 if the total staked tokens are 0 or the last time update is greater than or equal to the campaign
    /// end time.
    ///
    /// Requirements:
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  -  The campaign start time must not be in the future.
    function rewardsSinceLastSnapshot(uint256 campaignId) external view returns (uint128);

    /*//////////////////////////////////////////////////////////////////////////
                              STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Cancels the staking campaign and refunds rewards amount to the campaign admin.
    /// @dev Emits a {Transfer} and {CancelCampaign} events.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  - `msg.sender` must be the campaign admin.
    ///  - The campaign's start time must be in the future.
    ///
    /// @param campaignId The campaign ID to cancel.
    function cancelCampaign(uint256 campaignId) external returns (uint128 amountRefunded);

    /// @notice Claims the rewards earned by `msg.sender` in the specified campaign.
    /// @dev Emits a {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Sets the last time update for user.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  - The block timestamp must be greater than or equal to the campaign start time.
    ///  - Claimable rewards must be greater than 0.
    /// - `msg.value` must be greater than or equal to the minimum fee in wei for the campaign's admin.
    ///
    /// @param campaignId The campaign ID to claim rewards from.
    /// @return rewards The amount of rewards claimed, denoted in reward token's decimals.
    function claimRewards(uint256 campaignId) external payable returns (uint128 rewards);

    /// @notice Creates a new staking campaign and transfer the total reward amount from `msg.sender` to this contract.
    /// @dev Emits a {Transfer} and {CreateCampaign} events.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
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
    function createCampaign(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 totalRewards
    )
        external
        returns (uint256 campaignId);

    /// @notice Handles the hook call from the Lockup contract when a staked stream is cancelled. This adjusts the total
    /// staked tokens in the campaign accordingly.
    /// @dev Emits a {SnapshotRewards} event.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `streamId` associated with `msg.sender` must be staked in a valid campaign.
    ///
    /// @param streamId The ID of the staked stream on which cancel is called.
    /// @param sender The stream's sender, who canceled the stream.
    /// @param senderAmount The amount of tokens to be refunded to the stream's sender, denoted in units of the token's
    /// decimals.
    /// @param recipientAmount The amount of tokens left for the stream's recipient to withdraw, denoted in units of
    /// the token's decimals.
    ///
    /// @return selector The selector of this function needed to validate the hook.
    function onSablierLockupCancel(
        uint256 streamId,
        address sender,
        uint128 senderAmount,
        uint128 recipientAmount
    )
        external
        returns (bytes4 selector);

    /// @notice Snapshot global rewards and user rewards data for the specified campaign and user.
    /// @dev Emits a {SnapshotRewards} event.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  - User must be staking in the campaign.
    ///  - User snapshot's last time update must be less than the campaign end time.
    ///
    /// @param campaignId The campaign ID to snapshot rewards data for.
    /// @param user The address of the user to snapshot rewards data for.
    function snapshotRewards(uint256 campaignId, address user) external;

    /// @notice Stakes ERC20 staking token in the specified campaign.
    /// @dev Emits a {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the campaign start
    /// time.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
    ///  - Campaign end time must be in the future.
    ///  - `amount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the ERC20 token.
    ///
    /// @param campaignId The campaign ID to stake the ERC20 token in.
    function stakeERC20Token(uint256 campaignId, uint128 amount) external;

    /// @notice Stakes a Lockup stream in the specified campaign.
    /// @dev Emits a {SnapshotRewards}, {Transfer} and {StakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the campaign start
    /// time.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign or a canceled campaign.
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
    /// @dev Emits a {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `campaignId` must not reference a null campaign.
    ///  - `amount` must be greater than 0 and must not exceed the user's staked ERC20 amount in the campaign.
    ///
    /// @param campaignId The campaign ID to unstake the ERC20 token from.
    /// @param amount The amount of ERC20 tokens to unstake.
    function unstakeERC20Token(uint256 campaignId, uint128 amount) external;

    /// @notice Unstakes the Lockup stream from the specified campaign.
    /// @dev Emits a {SnapshotRewards}, {Transfer} and {UnstakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - The stream ID associated with `lockup` must be staked in a campaign.
    ///  - `msg.sender` must be the original owner of the stream stored in {StreamLookup} struct.
    ///
    /// @param lockup The Lockup contract associated with the stream ID.
    /// @param streamId The ID of the stream to unstake.
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external;

    /// @notice Whitelist a list of Lockup contracts enabling their stream IDs to be staked in any campaign.
    /// @dev Emits {LockupWhitelisted} event for each Lockup contract.
    ///
    /// Notes:
    ///  - It does nothing if the array is empty.
    ///  - The entire execution reverts if any of the requirements are not met for any of the Lockup contracts.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - Each lockup contract must not be the zero address.
    ///  - Each lockup contract must not already be whitelisted.
    ///  - Each lockup contract must return `true` when `isAllowedToHook` is called with this contract's address.
    ///  - `msg.sender` must be the comptroller contract.
    ///
    /// @param lockups The address of the Lockup contract to whitelist.
    function whitelistLockups(ISablierLockupNFT[] calldata lockups) external;
}
