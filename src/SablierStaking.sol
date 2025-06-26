// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ComptrollerManager } from "@sablier/evm-utils/src/ComptrollerManager.sol";
import { NoDelegateCall } from "@sablier/evm-utils/src/NoDelegateCall.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { SablierStakingState } from "./abstracts/SablierStakingState.sol";
import { ISablierLockupNFT } from "./interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "./interfaces/ISablierStaking.sol";
import { Errors } from "./libraries/Errors.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { GlobalSnapshot, Pool, StreamLookup, UserShares, UserSnapshot } from "./types/DataTypes.sol";

/// @title SablierStaking
/// @notice See the documentation in {ISablierStaking}.
contract SablierStaking is
    ComptrollerManager, // 1 inherited component
    ERC721Holder, // 1 inherited component
    ISablierStaking, // 4 inherited components
    NoDelegateCall, // 0 inherited components
    SablierStakingState // 1 inherited component
{
    using Helpers for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(address initialComptroller) ComptrollerManager(initialComptroller) {
        // Effect: Set the next pool ID to 1.
        nextPoolId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function claimableRewards(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        notClosed(poolId)
        returns (uint128)
    {
        // Check: the user address is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStaking_UserZeroAddress();
        }

        uint128 rewardsEarnedSinceLastSnapshot = _userRewardsSinceLastSnapshot(poolId, user);

        return _userSnapshot[user][poolId].rewards + rewardsEarnedSinceLastSnapshot;
    }

    /// @inheritdoc ISablierStaking
    function onSablierLockupWithdraw(
        uint256 streamId,
        address, /* caller */
        address, /* to */
        uint128 /* amount */
    )
        external
        view
        override
        noDelegateCall
        returns (bytes4)
    {
        // Cast `msg.sender` as the Lockup contract.
        ISablierLockupNFT lockup = ISablierLockupNFT(msg.sender);

        // Get the pool ID in which the stream ID is staked.
        uint256 poolId = _streamLookup[lockup][streamId].poolId;

        // Check: the pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        revert Errors.SablierStaking_WithdrawNotAllowed(poolId, lockup, streamId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRate(uint256 poolId) external view override notNull(poolId) isActive(poolId) returns (uint128) {
        // If the total amount staked is zero, return 0.
        if (_totalAmountStaked[poolId] == 0) {
            return 0;
        }

        return _rewardRate(poolId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRatePerTokenStaked(uint256 poolId)
        external
        view
        override
        notNull(poolId)
        isActive(poolId)
        returns (uint128)
    {
        uint128 totalAmountStaked = _totalAmountStaked[poolId];

        // If the total amount staked is zero, return 0.
        if (totalAmountStaked == 0) {
            return 0;
        }

        uint128 rewardPerSecond = _rewardRate(poolId);

        // Calculate the reward distributed per second.
        return rewardPerSecond / totalAmountStaked;
    }

    /// @inheritdoc ISablierStaking
    function rewardsPerTokenSinceLastSnapshot(uint256 poolId)
        external
        view
        override
        notNull(poolId)
        notClosed(poolId)
        returns (uint128)
    {
        // Check: the start time is not in the future.
        if (_pool[poolId].startTime > uint40(block.timestamp)) {
            revert Errors.SablierStaking_StartTimeInFuture(poolId, _pool[poolId].startTime);
        }

        // Get the rewards distributed since the last snapshot.
        uint128 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(poolId);

        // If the rewards distributed since the last snapshot is zero, return 0.
        if (rewardsDistributedSinceLastSnapshot == 0) {
            return 0;
        }

        // Else, calculate it.
        return rewardsDistributedSinceLastSnapshot / _totalAmountStaked[poolId];
    }

    /// @inheritdoc ISablierStaking
    function rewardsSinceLastSnapshot(uint256 poolId)
        external
        view
        override
        notNull(poolId)
        notClosed(poolId)
        returns (uint128)
    {
        // Check: the start time is not in the future.
        if (_pool[poolId].startTime > uint40(block.timestamp)) {
            revert Errors.SablierStaking_StartTimeInFuture(poolId, _pool[poolId].startTime);
        }

        return _rewardsDistributedSinceLastSnapshot(poolId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(ISablierLockupRecipient).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER-FACING STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function claimRewards(uint256 poolId)
        external
        payable
        override
        noDelegateCall
        notNull(poolId)
        notClosed(poolId)
        returns (uint128 rewards)
    {
        // TODO: change this to `calculateStakingMinFeeWeiFor` when it's implemented.
        uint256 minFeeWei = comptroller.calculateAirdropsMinFeeWeiFor(_pool[poolId].admin);

        // Check: fee paid is at least the minimum fee.
        if (msg.value < minFeeWei) {
            revert Errors.SablierStaking_InsufficientFeePayment(msg.value, minFeeWei);
        }

        // Check: the current timestamp is greater than or equal to the start time.
        if (block.timestamp < _pool[poolId].startTime) {
            revert Errors.SablierStaking_StartTimeInFuture(poolId, _pool[poolId].startTime);
        }

        // Effect: snapshot rewards data to the latest values.
        _snapshotRewards(poolId, msg.sender);

        // Load rewards from storage.
        rewards = _userSnapshot[msg.sender][poolId].rewards;

        // Check: `msg.sender` has rewards to claim.
        if (rewards == 0) {
            revert Errors.SablierStaking_ZeroClaimableRewards(poolId, msg.sender);
        }

        // Effect: set the rewards to 0.
        _userSnapshot[msg.sender][poolId].rewards = 0;

        // Effect: update the last update time.
        _userSnapshot[msg.sender][poolId].lastUpdateTime = uint40(block.timestamp);

        // Interaction: transfer the reward to `msg.sender`.
        IERC20 rewardToken = _pool[poolId].rewardToken;
        rewardToken.safeTransfer({ to: msg.sender, value: rewards });

        // Log the event.
        emit ClaimRewards(poolId, msg.sender, rewards);
    }

    /// @inheritdoc ISablierStaking
    function closePool(uint256 poolId)
        external
        override
        noDelegateCall
        notNull(poolId)
        notClosed(poolId)
        returns (uint128 amountRefunded)
    {
        // Load the pool data from storage.
        Pool memory pool = _pool[poolId];

        // Check: `msg.sender` is the pool admin.
        if (msg.sender != pool.admin) {
            revert Errors.SablierStaking_CallerNotPoolAdmin(poolId, msg.sender, pool.admin);
        }

        // Check: the start time is in the future.
        if (pool.startTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_RewardsPeriodActive(poolId, pool.startTime);
        }

        // Effect: set the pool as closed.
        _pool[poolId].wasClosed = true;

        // Interaction: refund the reward tokens to the pool admin.
        amountRefunded = pool.totalRewards;
        pool.rewardToken.safeTransfer({ to: msg.sender, value: amountRefunded });

        // Log the event.
        emit ClosePool(poolId);
    }

    /// @inheritdoc ISablierStaking
    function createPool(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 totalRewards
    )
        external
        override
        noDelegateCall
        returns (uint256 poolId)
    {
        // Check: admin is not the zero address.
        if (admin == address(0)) {
            revert Errors.SablierStaking_AdminZeroAddress();
        }

        // Check: the start time is greater than or equal to the current block timestamp.
        if (startTime < uint40(block.timestamp)) {
            revert Errors.SablierStaking_StartTimeInPast(startTime);
        }

        // Check: the end time is greater than the start time.
        if (endTime <= startTime) {
            revert Errors.SablierStaking_EndTimeNotGreaterThanStartTime(startTime, endTime);
        }

        // Check: staking token is not the zero address.
        if (address(stakingToken) == address(0)) {
            revert Errors.SablierStaking_StakingTokenZeroAddress();
        }

        // Check: the reward amount is not the zero address.
        if (address(rewardToken) == address(0)) {
            revert Errors.SablierStaking_RewardTokenZeroAddress();
        }

        // Check: total rewards is not zero.
        if (totalRewards == 0) {
            revert Errors.SablierStaking_RewardAmountZero();
        }

        // Load the next Pool ID from storage.
        poolId = nextPoolId;

        // Effect: store the pool parameters in the storage.
        _pool[poolId] = Pool({
            admin: admin,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: totalRewards,
            wasClosed: false
        });

        // Safe to use unchecked because it can't overflow.
        unchecked {
            // Effect: bump the next Pool ID.
            nextPoolId = poolId + 1;
        }

        // Interaction: transfer the rewards from the `msg.sender` to this contract.
        rewardToken.safeTransferFrom({ from: msg.sender, to: address(this), value: totalRewards });

        // Log the event.
        emit CreatePool(poolId, admin, stakingToken, rewardToken, startTime, endTime, totalRewards);
    }

    /// @inheritdoc ISablierStaking
    function onSablierLockupCancel(
        uint256 streamId,
        address, /* sender */
        uint128 senderAmount,
        uint128 /* recipientAmount */
    )
        external
        override
        noDelegateCall
        returns (bytes4)
    {
        StreamLookup memory streamLookup = _streamLookup[ISablierLockupNFT(msg.sender)][streamId];

        // Get the Pool ID in which the stream ID is staked.
        uint256 poolId = streamLookup.poolId;

        // Check: the Pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(ISablierLockupNFT(msg.sender), streamId);
        }

        // Get the owner of the stream.
        address owner = streamLookup.owner;

        // Effect: snapshot user rewards.
        _snapshotRewards(poolId, owner);

        // Effect: decrease the total amount staked in the pool.
        _totalAmountStaked[poolId] -= senderAmount;

        // Effect: decrease the user's share of stream amount staked.
        _userShares[owner][poolId].streamAmountStaked -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @inheritdoc ISablierStaking
    function snapshotRewards(
        uint256 poolId,
        address user
    )
        external
        override
        noDelegateCall
        notNull(poolId)
        notClosed(poolId)
    {
        // Get the user shares.
        UserShares memory userShares = _userShares[user][poolId];

        // Check: the total amount staked by user is not zero.
        if (userShares.directAmountStaked + userShares.streamAmountStaked == 0) {
            revert Errors.SablierStaking_NoStakedAmount(poolId, user);
        }

        uint40 lastUpdateTime = _userSnapshot[user][poolId].lastUpdateTime;

        // Check: the last update time is less than the end time.
        if (lastUpdateTime >= _pool[poolId].endTime) {
            revert Errors.SablierStaking_SnapshotNotAllowed(poolId, user, lastUpdateTime);
        }

        // Effect: snapshot rewards data to the latest values for `user`.
        _snapshotRewards(poolId, user);
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20Token(
        uint256 poolId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(poolId)
        notClosed(poolId)
    {
        // Retrieve the pool from storage.
        Pool memory pool = _pool[poolId];

        // Check: the end time is in the future.
        if (pool.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInFuture(poolId, pool.endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_StakingZeroAmount(poolId);
        }

        // Effect: update rewards for `msg.sender`.
        _snapshotRewards(poolId, msg.sender);

        // Effect: update total amount staked in the pool.
        _totalAmountStaked[poolId] += amount;

        // Effect: update direct amount staked by `msg.sender`.
        _userShares[msg.sender][poolId].directAmountStaked += amount;

        // Interaction: transfer the tokens from the `msg.sender` to this contract.
        pool.stakingToken.safeTransferFrom({ from: msg.sender, to: address(this), value: amount });

        // Log the event.
        emit StakeERC20Token(poolId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function stakeLockupNFT(
        uint256 poolId,
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        override
        noDelegateCall
        notNull(poolId)
        notClosed(poolId)
    {
        // Check: the lockup is whitelisted.
        if (!_lockupWhitelist[lockup]) {
            revert Errors.SablierStaking_LockupNotWhitelisted(lockup);
        }

        // Retrieve the pool from storage.
        Pool memory pool = _pool[poolId];

        // Check: the end time is in the future.
        if (pool.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInFuture(poolId, pool.endTime);
        }

        // Check: the stream's underlying token is the same as the pool's staking token.
        IERC20 underlyingToken = lockup.getUnderlyingToken(streamId);
        if (underlyingToken != pool.stakingToken) {
            revert Errors.SablierStaking_UnderlyingTokenDifferent(underlyingToken, pool.stakingToken);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Check: the amount in stream is not zero, i.e. the stream is not depleted.
        if (amountInStream == 0) {
            revert Errors.SablierStaking_DepletedStream(lockup, streamId);
        }

        // Effect: update rewards.
        _snapshotRewards(poolId, msg.sender);

        // Effect: update total amount staked in the pool.
        _totalAmountStaked[poolId] += amountInStream;

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][poolId];

        // Effect: update stream amount staked by `msg.sender`.
        _userShares[msg.sender][poolId].streamAmountStaked = userShares.streamAmountStaked + amountInStream;

        // Effect: update the number of streams staked by `msg.sender`.
        _userShares[msg.sender][poolId].streamsCount = userShares.streamsCount + 1;

        // Effect: update the `StreamLookup` mapping.
        _streamLookup[lockup][streamId] = StreamLookup({ poolId: poolId, owner: msg.sender });

        // Interaction: transfer the Lockup stream from the `msg.sender` to this contract.
        lockup.safeTransferFrom({ from: msg.sender, to: address(this), tokenId: streamId });

        // Log the event.
        emit StakeLockupNFT(poolId, msg.sender, lockup, streamId, amountInStream);
    }

    /// @inheritdoc ISablierStaking
    function unstakeERC20Token(uint256 poolId, uint128 amount) external override noDelegateCall notNull(poolId) {
        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_UnstakingZeroAmount(poolId);
        }

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][poolId];

        // Check: `amount` is not greater than the direct amount staked.
        if (amount > userShares.directAmountStaked) {
            revert Errors.SablierStaking_AmountExceedsStakedAmount(poolId, amount, userShares.directAmountStaked);
        }

        // Snapshot rewards if the pool has not been closed.
        if (!_pool[poolId].wasClosed) {
            // Effect: update rewards.
            _snapshotRewards(poolId, msg.sender);
        }
        // Otherwise, update the last update time only.
        else {
            // Effect: update the last update time.
            _globalSnapshot[poolId].lastUpdateTime = uint40(block.timestamp);
            _userSnapshot[msg.sender][poolId].lastUpdateTime = uint40(block.timestamp);
        }

        // Effect: update the global last update time.
        _globalSnapshot[poolId].lastUpdateTime = uint40(block.timestamp);

        // Safe to use `unchecked` because `amount` would not exceed `userShares.directAmountStaked`.
        unchecked {
            // Effect: reduce direct amount staked by `msg.sender`.
            _userShares[msg.sender][poolId].directAmountStaked = userShares.directAmountStaked - amount;
        }

        // Interaction: transfer the tokens to `msg.sender`.
        _pool[poolId].stakingToken.safeTransfer({ to: msg.sender, value: amount });

        // Log the event.
        emit UnstakeERC20Token(poolId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external override noDelegateCall {
        StreamLookup memory streamLookup = _streamLookup[lockup][streamId];

        // Get the Pool ID in which the stream ID is staked.
        uint256 poolId = streamLookup.poolId;

        // Check: the Pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        // Get the owner of the stream.
        address owner = streamLookup.owner;

        // Check: `msg.sender` is the original owner of the stream.
        if (msg.sender != owner) {
            revert Errors.SablierStaking_CallerNotStreamOwner(lockup, streamId, msg.sender, owner);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Snapshot rewards if the pool has not been closed.
        if (!_pool[poolId].wasClosed) {
            // Effect: update rewards.
            _snapshotRewards(poolId, msg.sender);
        }
        // Otherwise, update the last update time only.
        else {
            // Effect: update the last update time.
            _globalSnapshot[poolId].lastUpdateTime = uint40(block.timestamp);
            _userSnapshot[msg.sender][poolId].lastUpdateTime = uint40(block.timestamp);
        }

        // Effect: reduce total amount staked in the pool.
        _totalAmountStaked[poolId] -= amountInStream;

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][poolId];

        // Effect: reduce stream amount staked by `msg.sender`.
        _userShares[msg.sender][poolId].streamAmountStaked = userShares.streamAmountStaked - amountInStream;

        // Effect: reduce the number of streams staked by `msg.sender`.
        _userShares[msg.sender][poolId].streamsCount = userShares.streamsCount - 1;

        // Effect: delete the `StreamLookup` mapping.
        delete _streamLookup[lockup][streamId];

        // Interaction: transfer the Lockup stream to `msg.sender`.
        lockup.safeTransferFrom({ from: address(this), to: msg.sender, tokenId: streamId });

        // Log the event.
        emit UnstakeLockupNFT(poolId, msg.sender, lockup, streamId);
    }

    /// @inheritdoc ISablierStaking
    function whitelistLockups(ISablierLockupNFT[] calldata lockups) external override noDelegateCall onlyComptroller {
        uint256 length = lockups.length;

        for (uint256 i = 0; i < length; ++i) {
            // Check: the lockup contract is not the zero address.
            if (address(lockups[i]) == address(0)) {
                revert Errors.SablierStaking_LockupZeroAddress(i);
            }

            // Check: the lockup contract is not already whitelisted.
            if (_lockupWhitelist[lockups[i]]) {
                revert Errors.SablierStaking_LockupAlreadyWhitelisted(i, lockups[i]);
            }

            // Check: the lockup contract returns `true` when `isAllowedToHook` is called.
            if (!lockups[i].isAllowedToHook(address(this))) {
                revert Errors.SablierStaking_UnsupportedOnAllowedToHook(i, lockups[i]);
            }

            // Effect: whitelist the lockup contract.
            _lockupWhitelist[lockups[i]] = true;

            // Log the event.
            emit LockupWhitelisted(address(comptroller), lockups[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculates the latest cumulative rewards distributed per ERC20 token.
    function _latestRewardsDistributedPerTokenScaled(uint256 poolId)
        private
        view
        returns (uint256 rewardsPerTokenScaled)
    {
        // Load the global snapshot into memory.
        GlobalSnapshot memory globalSnapshot = _globalSnapshot[poolId];

        rewardsPerTokenScaled = globalSnapshot.rewardsDistributedPerTokenScaled;

        // Get the rewards distributed since the last snapshot.
        uint256 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(poolId);

        if (rewardsDistributedSinceLastSnapshot > 0) {
            // Get the rewards distributed per ERC20 token since the last snapshot, by scaling up.
            uint256 rewardsPerTokenSinceLastSnapshotScaled =
                rewardsDistributedSinceLastSnapshot.scaleUp() / _totalAmountStaked[poolId];

            // Calculate the cumulative rewards distributed per ERC20 token.
            rewardsPerTokenScaled += rewardsPerTokenSinceLastSnapshotScaled;
        }

        return rewardsPerTokenScaled;
    }

    /// @notice Calculates the reward distributed per second without checking if the pool is active.
    function _rewardRate(uint256 poolId) private view returns (uint128) {
        Pool memory pool = _pool[poolId];

        // Safe to use `unchecked` because the following calculations cannot overflow.
        unchecked {
            // Calculate the reward period.
            uint40 rewardPeriod = pool.endTime - pool.startTime;

            // Return the reward rate.
            return pool.totalRewards / rewardPeriod;
        }
    }

    /// @notice Calculates cumulative rewards distributed since the last snapshot.
    /// @dev Returns 0 if:
    ///  - The total amount staked is 0.
    ///  - The start time is in the future.
    ///  - The last time update is greater than or equal to the end time.
    function _rewardsDistributedSinceLastSnapshot(uint256 poolId) private view returns (uint128 rewardsDistributed) {
        // If the total amount staked is 0, return 0.
        if (_totalAmountStaked[poolId] == 0) {
            return 0;
        }

        Pool memory pool = _pool[poolId];

        // If the start time is in the future, return 0.
        if (uint40(block.timestamp) < pool.startTime) {
            return 0;
        }

        uint40 lastUpdateTime = _globalSnapshot[poolId].lastUpdateTime;

        // If the last time update is greater than or equal to the end time, return 0.
        if (lastUpdateTime >= pool.endTime) {
            return 0;
        }

        // Define variables to store time range for rewards calculation.
        uint40 endingTimestamp;
        uint40 startingTimestamp;

        // If the last update time is less than the start time, the starting timestamp is the start time.
        if (lastUpdateTime <= pool.startTime) {
            startingTimestamp = pool.startTime;
        } else {
            startingTimestamp = lastUpdateTime;
        }

        // If the end time has passed, the ending timestamp is the pool end time.
        if (pool.endTime <= uint40(block.timestamp)) {
            endingTimestamp = pool.endTime;
        } else {
            endingTimestamp = uint40(block.timestamp);
        }

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the elapsed time and the total reward period.
            uint256 elapsedTime = endingTimestamp - startingTimestamp;
            uint256 rewardsPeriod = pool.endTime - pool.startTime;

            // Calculate the total rewards distributed since the last snapshot.
            rewardsDistributed = ((pool.totalRewards * elapsedTime) / rewardsPeriod).toUint128();
        }

        return rewardsDistributed;
    }

    /// @dev Calculates the rewards earned by the user since the last snapshot.
    function _userRewardsSinceLastSnapshot(uint256 poolId, address user) private view returns (uint128) {
        UserShares memory userShares = _userShares[user][poolId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userShares.directAmountStaked + userShares.streamAmountStaked;

        // If the user has no tokens staked, return 0.
        if (userTotalAmountStaked == 0) {
            return 0;
        }

        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        uint256 rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(poolId);

        // Calculate the rewards earned per ERC20 token by the user since the last snapshot.
        uint256 userRewardsPerTokenSinceLastSnapshotScaled =
            rewardsPerTokenScaled - _userSnapshot[user][poolId].rewardsEarnedPerTokenScaled;

        // Calculate the rewards earned by the user since the last snapshot.
        uint256 rewardsEarnedScaled = userRewardsPerTokenSinceLastSnapshotScaled * userTotalAmountStaked;

        // Return the scaled down amount.
        return rewardsEarnedScaled.scaleDown().toUint128();
    }

    /*//////////////////////////////////////////////////////////////////////////
                          PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Snapshots rewards data for the specified pool and user.
    function _snapshotRewards(uint256 poolId, address user) private {
        // Update the global snapshot.
        uint256 rewardsPerTokenScaled = _updateGlobalSnapshot(poolId);

        // Update the user snapshot.
        uint128 userRewards = _updateUserSnapshot(poolId, user, rewardsPerTokenScaled);

        // Log the event.
        emit SnapshotRewards({
            poolId: poolId,
            lastUpdateTime: uint40(block.timestamp),
            rewardsDistributedPerTokenScaled: rewardsPerTokenScaled,
            user: user,
            userRewards: userRewards
        });
    }

    /// @notice Private function to update the global snapshot.
    function _updateGlobalSnapshot(uint256 poolId) private returns (uint256 rewardsPerTokenScaled) {
        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(poolId);

        // Effect: update the rewards distributed per ERC20 token.
        _globalSnapshot[poolId].rewardsDistributedPerTokenScaled = rewardsPerTokenScaled;

        // Effect: update the last time update.
        _globalSnapshot[poolId].lastUpdateTime = uint40(block.timestamp);
    }

    /// @dev Private function to update the user snapshot.
    function _updateUserSnapshot(
        uint256 poolId,
        address user,
        uint256 rewardsPerTokenScaled
    )
        private
        returns (uint128 userRewards)
    {
        UserSnapshot memory userSnapshot = _userSnapshot[user][poolId];
        UserShares memory userShares = _userShares[user][poolId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userShares.directAmountStaked + userShares.streamAmountStaked;

        // Update the user snapshot if the last time update is less than the end time.
        if (userSnapshot.lastUpdateTime < _pool[poolId].endTime) {
            // If the user has tokens staked, update the user rewards earned.
            if (userTotalAmountStaked > 0) {
                // Compute the rewards earned per ERC20 token by the user since the previous snapshot.
                uint256 userRewardsPerTokenSinceLastSnapshotScaled =
                    rewardsPerTokenScaled - userSnapshot.rewardsEarnedPerTokenScaled;

                // Compute the new rewards earned by the user since the last snapshot.
                uint256 userRewardsSinceLastSnapshotScaled =
                    userRewardsPerTokenSinceLastSnapshotScaled * userTotalAmountStaked;

                // Scale down the rewards earned by the user since the last snapshot.
                uint128 userRewardsSinceLastSnapshot = userRewardsSinceLastSnapshotScaled.scaleDown().toUint128();

                // Effect: update the rewards earned by the user.
                userRewards = userSnapshot.rewards + userRewardsSinceLastSnapshot;
                _userSnapshot[user][poolId].rewards = userRewards;
            }

            // Effect: update the rewards earned per ERC20 token by the user.
            _userSnapshot[user][poolId].rewardsEarnedPerTokenScaled = rewardsPerTokenScaled;

            // Effect: update the last time update.
            _userSnapshot[user][poolId].lastUpdateTime = uint40(block.timestamp);
        }
    }
}
