// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import { IComptrollerable } from "@sablier/evm-utils/src/interfaces/IComptrollerable.sol";

import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";
import { ISablierStakingState } from "./ISablierStakingState.sol";

/// @title ISablierStaking
/// @notice Creates and manages staking pools allowing staking of both ERC20 tokens and Sablier Lockup NFTs.
interface ISablierStaking is
    IComptrollerable, // 0 inherited components
    IERC165, // 0 inherited components
    IERC721Receiver, // 0 inherited components
    ISablierStakingState // 0 inherited components
{
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when rewards are claimed.
    event ClaimRewards(uint256 indexed poolId, address indexed user, uint128 amountClaimed);

    /// @notice Emitted when a new staking round is configured on an existing pool.
    event ConfigureNextRound(uint256 indexed poolId, uint40 newEndTime, uint40 newStartTime, uint128 newRewardAmount);

    /// @notice Emitted when a new pool is created.
    event CreatePool(
        uint256 indexed poolId,
        address indexed admin,
        uint40 endTime,
        uint128 rewardAmount,
        IERC20 rewardToken,
        IERC20 indexed stakingToken,
        uint40 startTime
    );

    /// @notice Emitted when a Lockup contract is whitelisted.
    event LockupWhitelisted(address indexed comptroller, ISablierLockupNFT indexed lockup);

    /// @notice Emitted when a user stakes ERC20 tokens in a pool.
    event StakeERC20Token(uint256 indexed poolId, address indexed user, uint256 amountStaked);

    /// @notice Emitted when a user stakes a Lockup stream in a pool.
    event StakeLockupNFT(
        uint256 indexed poolId,
        address indexed user,
        ISablierLockupNFT indexed lockup,
        uint256 streamId,
        uint128 underlyingTokenAmount
    );

    /// @notice Emitted when a user unstakes ERC20 tokens from a pool.
    event UnstakeERC20Token(uint256 indexed poolId, address indexed user, uint256 amountUnstaked);

    /// @notice Emitted when a user unstakes a Lockup stream from a pool.
    event UnstakeLockupNFT(
        uint256 indexed poolId, address indexed user, ISablierLockupNFT indexed lockup, uint256 streamId
    );

    /// @notice Emitted when the pool and user rewards are updated.
    event UpdateRewards(
        uint256 indexed poolId,
        uint40 lastUpdateTime,
        uint256 rewardsDistributedPerTokenScaled,
        address indexed user,
        uint128 pendingRewards
    );

    /*//////////////////////////////////////////////////////////////////////////
                                READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculates the minimum fee in wei required to claim rewards from the given pool ID.
    /// @dev Reverts if `poolId` references a non-existent pool.
    /// @param poolId The pool ID for the query.
    function calculateMinFeeWei(uint256 poolId) external view returns (uint256);

    /// @notice Returns the amount of reward ERC20 tokens available to claim by the user.
    /// @dev Reverts if `poolId` references a non-existent pool, or if `user` is the zero address.
    function claimableRewards(uint256 poolId, address user) external view returns (uint128);

    /// @notice Reverts on the hook call from the Lockup contract when a withdraw is called on a staked stream
    /// @dev This function reverts and does not permit withdrawing from a staked stream
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `streamId` must be staked in a pool.
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

    /// @notice Returns the amount of reward ERC20 tokens distributed every second.
    /// @dev Reverts if `poolId` references a non-existent pool or is not active.
    function rewardRate(uint256 poolId) external view returns (uint128);

    /// @notice Returns the amount of reward ERC20 token that each staked ERC20 token is earning every second. Returns 0
    /// if total staked tokens are 0.
    /// @dev Reverts if `poolId` references a non-existent pool or is not active.
    function rewardRatePerTokenStaked(uint256 poolId) external view returns (uint128);

    /// @notice Calculates rewards distributed per ERC20 token since the last snapshot.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function rewardsPerTokenSinceLastSnapshot(uint256 poolId) external view returns (uint128);

    /// @notice Calculates rewards distributed since the last snapshot.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function rewardsSinceLastSnapshot(uint256 poolId) external view returns (uint128);

    /*//////////////////////////////////////////////////////////////////////////
                              STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Claims the rewards earned by `msg.sender` in the specified pool.
    /// @dev Emits {UpdateRewards}, {Transfer} and {ClaimRewards} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Sets the last time update for user.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - Claimable rewards must be greater than 0.
    /// - `msg.value` must be greater than or equal to the minimum fee in wei for the pool's admin.
    /// - `feeOnRewards` must be less than or equal to {MAX_FEE_ON_REWARDS}.
    ///
    /// @param poolId The Pool ID to claim rewards from.
    /// @param feeOnRewards An optional fee to be deducted from the rewards claimed, denoted as fixed-point number where
    /// 1e18 is 100%.
    /// @return amountClaimed The amount of rewards claimed, denoted in reward token's decimals.
    function claimRewards(uint256 poolId, UD60x18 feeOnRewards) external payable returns (uint128 amountClaimed);

    /// @notice Configures the next staking round for the specified pool.
    /// @dev Emits a {UpdateRewards} and {ConfigureNextRound} events.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - `msg.sender` must be the pool admin.
    ///  - `poolId` must reference a pool with an end time in the past.
    ///  - `newStartTime` must be greater than or equal to the `block.timestamp`.
    ///  - `newEndTime` must be greater than new `startTime`.
    ///  - `rewardAmount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the `rewardAmount` of reward ERC20 token.
    ///
    /// @param poolId The pool ID for which to configure the next staking round.
    /// @param newEndTime The end time for the next rewards period, denoted in UNIX timestamp.
    /// @param newStartTime The start time for the next rewards period, denoted in UNIX timestamp.
    /// @param newRewardAmount The amount of reward tokens to distribute during the next rewards period, denoted in
    /// reward token's decimals.
    function configureNextRound(
        uint256 poolId,
        uint40 newEndTime,
        uint40 newStartTime,
        uint128 newRewardAmount
    )
        external;

    /// @notice Creates a new staking pool and transfer the reward amount from `msg.sender` to this contract.
    /// @dev Emits a {Transfer} and {CreatePool} events.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `admin` must not be the zero address.
    ///  - `startTime` must be greater than or equal to the `block.timestamp`.
    ///  - `startTime` must be less than `endTime`.
    ///  - `stakingToken` must not be the zero address.
    ///  - `rewardToken` must not be the zero address.
    ///  - `rewardAmount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the `rewardAmount` of reward ERC20 token.
    ///
    /// @param admin The admin of the pool.
    /// @param stakingToken The ERC20 token permitted for staking either directly or through Lockup streams.
    /// @param startTime The start time of the rewards period, denoted in UNIX timestamp.
    /// @param endTime The end time of the rewards period, denoted in UNIX timestamp.
    /// @param rewardToken The ERC20 token that will be distributed as rewards.
    /// @param rewardAmount The amount of reward tokens to distribute, denoted in reward token's decimals.
    /// @return poolId The ID of the newly created pool.
    function createPool(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 rewardAmount
    )
        external
        returns (uint256 poolId);

    /// @notice Handles the hook call from the Lockup contract when a staked stream is cancelled. This adjusts the total
    /// staked tokens in the pool accordingly.
    /// @dev Emits a {UpdateRewards} event.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `streamId` associated with `msg.sender` must be staked in a valid pool.
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

    /// @notice Snapshot global rewards and user rewards data for the specified pool and user.
    /// @dev Emits a {UpdateRewards} event.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - User must be staking in the pool.
    ///  - User snapshot's last time update must be less than the end time.
    ///
    /// @param poolId The Pool ID to snapshot rewards data for.
    /// @param user The address of the user to snapshot rewards data for.
    function snapshotRewards(uint256 poolId, address user) external;

    /// @notice Stakes ERC20 staking token in the specified pool.
    /// @dev Emits {UpdateRewards}, {Transfer} and {StakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the start time.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - Pool end time must be in the future.
    ///  - `amount` must be greater than 0.
    ///  - `msg.sender` must have approved this contract to spend the ERC20 token.
    ///
    /// @param poolId The Pool ID to stake the ERC20 token in.
    function stakeERC20Token(uint256 poolId, uint128 amount) external;

    /// @notice Stakes a Lockup stream in the specified pool.
    /// @dev Emits {UpdateRewards}, {Transfer} and {StakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Users can start staking before the start time but the rewards can only be earned after the start time.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - `lockup` must be a whitelisted Lockup contract.
    ///  - Pool end time must be in the future.
    ///  - Stream's underlying token must be same as the pool's staking token.
    ///  - The amount in stream must not be zero, i.e. it must not be depleted.
    ///  - `msg.sender` must have approved this contract to spend the stream ID.
    ///
    /// @param poolId The Pool ID to stake the Lockup stream in.
    /// @param lockup The Lockup contract associated with the stream ID.
    /// @param streamId The ID of the stream to stake.
    function stakeLockupNFT(uint256 poolId, ISablierLockupNFT lockup, uint256 streamId) external;

    /// @notice Unstakes the amount specified of the staking token from the specified pool.
    /// @dev Emits {UpdateRewards}, {Transfer} and {UnstakeERC20Token} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `poolId` must not reference a non-existent pool.
    ///  - `amount` must be greater than 0 and must not exceed the user's staked ERC20 amount in the pool.
    ///
    /// @param poolId The Pool ID to unstake the ERC20 token from.
    /// @param amount The amount of ERC20 tokens to unstake.
    function unstakeERC20Token(uint256 poolId, uint128 amount) external;

    /// @notice Unstakes the Lockup stream from the specified pool.
    /// @dev Emits {UpdateRewards}, {Transfer} and {UnstakeLockupNFT} events.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///  - Unstaking does not claim any rewards.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - The stream ID associated with `lockup` must be staked in a pool.
    ///  - `msg.sender` must be the original owner of the stream stored in {StreamLookup} struct.
    ///
    /// @param lockup The Lockup contract associated with the stream ID.
    /// @param streamId The ID of the stream to unstake.
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external;

    /// @notice Whitelist a list of Lockup contracts enabling their stream IDs to be staked in any pool.
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
