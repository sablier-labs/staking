// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud, UD60x18, ZERO } from "@prb/math/src/UD60x18.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Comptrollerable } from "@sablier/evm-utils/src/Comptrollerable.sol";
import { ISablierComptroller } from "@sablier/evm-utils/src/interfaces/ISablierComptroller.sol";
import { NoDelegateCall } from "@sablier/evm-utils/src/NoDelegateCall.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { SablierStakingState } from "./abstracts/SablierStakingState.sol";
import { ISablierLockupNFT } from "./interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "./interfaces/ISablierStaking.sol";
import { Errors } from "./libraries/Errors.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { Pool, StreamLookup, UserAccount } from "./types/DataTypes.sol";

/// @title SablierStaking
/// @notice See the documentation in {ISablierStaking}.
contract SablierStaking is
    Comptrollerable, // 1 inherited component
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

    constructor(address initialComptroller) Comptrollerable(initialComptroller) {
        // Effect: Set the next pool ID to 1.
        nextPoolId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function calculateMinFeeWei(uint256 poolId) external view override notNull(poolId) returns (uint256) {
        // Calculate the minimum fee in wei.
        return comptroller.calculateMinFeeWeiFor(ISablierComptroller.Protocol.Staking, _pools[poolId].admin);
    }

    /// @inheritdoc ISablierStaking
    function claimableRewards(uint256 poolId, address user) external view notNull(poolId) returns (uint128) {
        // Check: the user address is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStaking_UserZeroAddress();
        }

        // Load the struct in memory.
        UserAccount memory userAccount = _userAccounts[user][poolId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userAccount.directAmountStaked + userAccount.streamAmountStaked;

        uint128 rewardsEarnedSinceLastSnapshot;

        // If the user has tokens staked, calculate rewards earned since last snapshot.
        if (userTotalAmountStaked > 0) {
            // Get the latest value of the cumulative rewards distributed per ERC20 token.
            uint256 rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(poolId);

            // Calculate the rewards earned per ERC20 token by the user since the last snapshot.
            uint256 userRewardsPerTokenSinceLastSnapshotScaled =
                rewardsPerTokenScaled - userAccount.rewardsEarnedPerTokenScaled;

            // Calculate the rewards earned by the user since the last snapshot.
            uint256 rewardsEarnedScaled = userRewardsPerTokenSinceLastSnapshotScaled * userTotalAmountStaked;

            // Scale down the amount.
            rewardsEarnedSinceLastSnapshot = rewardsEarnedScaled.scaleDown().toUint128();
        }

        return userAccount.pendingRewards + rewardsEarnedSinceLastSnapshot;
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
        uint256 poolId = _streamsLookup[lockup][streamId].poolId;

        // Check: the pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        revert Errors.SablierStaking_WithdrawNotAllowed(poolId, lockup, streamId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRate(uint256 poolId) external view override notNull(poolId) isActive(poolId) returns (uint128) {
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
        uint128 totalStakedAmount = _pools[poolId].totalStakedAmount;

        // If the total staked amount is zero, return 0.
        if (totalStakedAmount == 0) {
            return 0;
        }

        uint128 rewardPerSecond = _rewardRate(poolId);

        // Calculate the reward distributed per second.
        return rewardPerSecond / totalStakedAmount;
    }

    /// @inheritdoc ISablierStaking
    function rewardsPerTokenSinceLastSnapshot(uint256 poolId)
        external
        view
        override
        notNull(poolId)
        returns (uint128)
    {
        // Get the rewards distributed since the last snapshot.
        uint128 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(poolId);

        // If the rewards distributed since the last snapshot is zero, return 0.
        if (rewardsDistributedSinceLastSnapshot == 0) {
            return 0;
        }

        // Else, calculate it.
        return rewardsDistributedSinceLastSnapshot / _pools[poolId].totalStakedAmount;
    }

    /// @inheritdoc ISablierStaking
    function rewardsSinceLastSnapshot(uint256 poolId) external view override notNull(poolId) returns (uint128) {
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
    function claimRewards(
        uint256 poolId,
        UD60x18 feeOnRewards
    )
        external
        payable
        override
        noDelegateCall
        notNull(poolId)
        returns (uint128 rewardsClaimed)
    {
        // Get minimum fee in wei for the pool admin.
        uint256 minFeeWei =
            comptroller.calculateMinFeeWeiFor(ISablierComptroller.Protocol.Staking, _pools[poolId].admin);

        uint256 feePaid = msg.value;

        // Check: fee paid is at least the minimum fee.
        if (feePaid < minFeeWei) {
            revert Errors.SablierStaking_InsufficientFeePayment(feePaid, minFeeWei);
        }

        // Check: the fee on rewards does not exceed the maximum fee.
        if (feeOnRewards > MAX_FEE_ON_REWARDS) {
            revert Errors.SablierStaking_FeeOnRewardsTooHigh(feeOnRewards, MAX_FEE_ON_REWARDS);
        }

        // Effect: update rewards data to the latest values.
        _updateRewards(poolId, msg.sender);

        // Load rewards from storage.
        rewardsClaimed = _userAccounts[msg.sender][poolId].pendingRewards;

        // Check: `msg.sender` has rewards to claim.
        if (rewardsClaimed == 0) {
            revert Errors.SablierStaking_ZeroClaimableRewards(poolId, msg.sender);
        }

        // Effect: set the rewards to 0.
        _userAccounts[msg.sender][poolId].pendingRewards = 0;

        // Interaction: transfer the fee paid to comptroller if it's greater than 0.
        if (feePaid > 0) {
            (bool success,) = address(comptroller).call{ value: feePaid }("");

            // Revert if the transfer fails.
            if (!success) {
                revert Errors.SablierStaking_MinFeeTransferFailed(address(comptroller), feePaid);
            }
        }

        // Get the reward token.
        IERC20 rewardToken = _pools[poolId].rewardToken;

        // Interaction: calculate and transfer the fee in reward token if it's greater than 0.
        if (feeOnRewards > ZERO) {
            uint128 feeInRewardToken = ud(rewardsClaimed).mul(feeOnRewards).intoUint128();

            // Interaction: transfer the fee to comptroller.
            rewardToken.safeTransfer({ to: address(comptroller), value: feeInRewardToken });

            // Adjust the amount to claim.
            rewardsClaimed -= feeInRewardToken;
        }

        // Interaction: transfer the amount `msg.sender`.
        rewardToken.safeTransfer({ to: msg.sender, value: rewardsClaimed });

        // Log the event.
        emit ClaimRewards(poolId, msg.sender, rewardsClaimed);
    }

    /// @inheritdoc ISablierStaking
    function configureNextRound(
        uint256 poolId,
        uint40 newStartTime,
        uint40 newEndTime,
        uint128 newRewardAmount
    )
        external
        override
        noDelegateCall
        notNull(poolId)
    {
        // Load the pool.
        Pool storage pool = _pools[poolId];

        // Check: `msg.sender` is the pool admin.
        if (msg.sender != pool.admin) {
            revert Errors.SablierStaking_CallerNotPoolAdmin(poolId, msg.sender, pool.admin);
        }

        uint40 blockTimestamp = uint40(block.timestamp);

        // Check: pool end time is in the past.
        if (pool.endTime >= blockTimestamp) {
            revert Errors.SablierStaking_EndTimeNotInPast(poolId, pool.endTime);
        }

        // Check: the new start time is greater than or equal to the current block timestamp.
        if (newStartTime < blockTimestamp) {
            revert Errors.SablierStaking_StartTimeInPast(newStartTime);
        }

        // Check: the new start time is less than the new end time.
        if (newEndTime <= newStartTime) {
            revert Errors.SablierStaking_StartTimeNotLessThanEndTime(newStartTime, newEndTime);
        }

        // Check: the new reward amount is greater than 0.
        if (newRewardAmount == 0) {
            revert Errors.SablierStaking_RewardAmountZero();
        }

        // Effect: update rewards.
        _updateRewards(poolId, msg.sender);

        // Effect: set the next staking round parameters.
        pool.endTime = newEndTime;
        pool.startTime = newStartTime;
        pool.rewardAmount = newRewardAmount;

        // Interaction: transfer the reward amount from the `msg.sender` to this contract.
        pool.rewardToken.safeTransferFrom({ from: msg.sender, to: address(this), value: newRewardAmount });

        // Log the event.
        emit ConfigureNextRound(poolId, newStartTime, newEndTime, newRewardAmount);
    }

    /// @inheritdoc ISablierStaking
    function createPool(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 rewardAmount
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

        // Check: start time is less than end time.
        if (endTime <= startTime) {
            revert Errors.SablierStaking_StartTimeNotLessThanEndTime(startTime, endTime);
        }

        // Check: staking token is not the zero address.
        if (address(stakingToken) == address(0)) {
            revert Errors.SablierStaking_StakingTokenZeroAddress();
        }

        // Check: the reward amount is not the zero address.
        if (address(rewardToken) == address(0)) {
            revert Errors.SablierStaking_RewardTokenZeroAddress();
        }

        // Check: reward amount is not zero.
        if (rewardAmount == 0) {
            revert Errors.SablierStaking_RewardAmountZero();
        }

        // Load the next Pool ID from storage.
        poolId = nextPoolId;

        // Effect: store the pool parameters in the storage.
        _pools[poolId] = Pool({
            admin: admin,
            endTime: endTime,
            lastUpdateTime: 0,
            rewardAmount: rewardAmount,
            rewardsDistributedPerTokenScaled: 0,
            rewardToken: rewardToken,
            stakingToken: stakingToken,
            startTime: startTime,
            totalStakedAmount: 0
        });

        // Safe to use unchecked because it can't overflow.
        unchecked {
            // Effect: bump the next Pool ID.
            nextPoolId = poolId + 1;
        }

        // Interaction: transfer the reward amount from the `msg.sender` to this contract.
        rewardToken.safeTransferFrom({ from: msg.sender, to: address(this), value: rewardAmount });

        // Log the event.
        emit CreatePool({
            poolId: poolId,
            admin: admin,
            endTime: endTime,
            rewardToken: rewardToken,
            stakingToken: stakingToken,
            startTime: startTime,
            rewardAmount: rewardAmount
        });
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
        // Get the Pool ID in which the stream ID is staked.
        uint256 poolId = _streamsLookup[ISablierLockupNFT(msg.sender)][streamId].poolId;

        // Check: the Pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(ISablierLockupNFT(msg.sender), streamId);
        }

        // Get the owner of the stream.
        address owner = _streamsLookup[ISablierLockupNFT(msg.sender)][streamId].owner;

        // Effect: snapshot user rewards.
        _updateRewards(poolId, owner);

        // Effect: decrease the total staked amount in the pool.
        _pools[poolId].totalStakedAmount -= senderAmount;

        // Effect: decrease the user's share of stream amount staked.
        _userAccounts[owner][poolId].streamAmountStaked -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @inheritdoc ISablierStaking
    function snapshotRewards(uint256 poolId, address user) external override noDelegateCall notNull(poolId) {
        // Check: the total amount staked by user is not zero.
        if (_userAccounts[user][poolId].directAmountStaked + _userAccounts[user][poolId].streamAmountStaked == 0) {
            revert Errors.SablierStaking_NoStakedAmount(poolId, user);
        }

        // Effect: update rewards data to the latest values for `user`.
        _updateRewards(poolId, user);
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20Token(uint256 poolId, uint128 amount) external override noDelegateCall notNull(poolId) {
        // Check: the end time is in the future.
        if (_pools[poolId].endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInFuture(poolId, _pools[poolId].endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_StakingZeroAmount(poolId);
        }

        // Effect: update rewards for `msg.sender`.
        _updateRewards(poolId, msg.sender);

        // Effect: update total staked amount in the pool.
        _pools[poolId].totalStakedAmount += amount;

        // Effect: update direct amount staked by `msg.sender`.
        _userAccounts[msg.sender][poolId].directAmountStaked += amount;

        // Interaction: transfer the tokens from the `msg.sender` to this contract.
        _pools[poolId].stakingToken.safeTransferFrom({ from: msg.sender, to: address(this), value: amount });

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
    {
        // Check: the lockup is whitelisted.
        if (!_lockupWhitelists[lockup]) {
            revert Errors.SablierStaking_LockupNotWhitelisted(lockup);
        }

        uint40 poolEndTime = _pools[poolId].endTime;

        // Check: the end time is in the future.
        if (poolEndTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInFuture(poolId, poolEndTime);
        }

        // Check: the stream's underlying token is the same as the pool's staking token.
        IERC20 underlyingToken = lockup.getUnderlyingToken(streamId);
        if (underlyingToken != _pools[poolId].stakingToken) {
            revert Errors.SablierStaking_UnderlyingTokenDifferent(underlyingToken, _pools[poolId].stakingToken);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Check: the amount in stream is not zero, i.e. the stream is not depleted.
        if (amountInStream == 0) {
            revert Errors.SablierStaking_DepletedStream(lockup, streamId);
        }

        // Effect: update rewards.
        _updateRewards(poolId, msg.sender);

        // Effect: update total staked amount in the pool.
        _pools[poolId].totalStakedAmount += amountInStream;

        // Effect: update stream amount staked by `msg.sender`.
        _userAccounts[msg.sender][poolId].streamAmountStaked += amountInStream;

        // Effect: update the `StreamLookup` mapping.
        _streamsLookup[lockup][streamId] = StreamLookup({ poolId: poolId, owner: msg.sender });

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

        // Check: `amount` is not greater than the direct amount staked.
        if (amount > _userAccounts[msg.sender][poolId].directAmountStaked) {
            revert Errors.SablierStaking_Overflow(poolId, amount, _userAccounts[msg.sender][poolId].directAmountStaked);
        }

        // Effect: update rewards.
        _updateRewards(poolId, msg.sender);

        // Effect: reduce total staked amount in the pool.
        _pools[poolId].totalStakedAmount -= amount;

        // Safe to use `unchecked` because `amount` would not exceed `directAmountStaked`.
        unchecked {
            // Effect: reduce direct amount staked by `msg.sender`.
            _userAccounts[msg.sender][poolId].directAmountStaked -= amount;
        }

        // Interaction: transfer the tokens to `msg.sender`.
        _pools[poolId].stakingToken.safeTransfer({ to: msg.sender, value: amount });

        // Log the event.
        emit UnstakeERC20Token(poolId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external override noDelegateCall {
        uint256 poolId = _streamsLookup[lockup][streamId].poolId;

        // Check: the Pool ID is not zero.
        if (poolId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        // Check: `msg.sender` is the original owner of the stream.
        if (msg.sender != _streamsLookup[lockup][streamId].owner) {
            revert Errors.SablierStaking_CallerNotStreamOwner(
                lockup, streamId, msg.sender, _streamsLookup[lockup][streamId].owner
            );
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Effect: update rewards.
        _updateRewards(poolId, msg.sender);

        // Effect: reduce total staked amount in the pool.
        _pools[poolId].totalStakedAmount -= amountInStream;

        // Effect: reduce stream amount staked by `msg.sender`.
        _userAccounts[msg.sender][poolId].streamAmountStaked -= amountInStream;

        // Effect: delete the `StreamLookup` mapping.
        delete _streamsLookup[lockup][streamId];

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
            if (_lockupWhitelists[lockups[i]]) {
                revert Errors.SablierStaking_LockupAlreadyWhitelisted(i, lockups[i]);
            }

            // Check: the lockup contract returns `true` when `isAllowedToHook` is called.
            if (!lockups[i].isAllowedToHook(address(this))) {
                revert Errors.SablierStaking_UnsupportedOnAllowedToHook(i, lockups[i]);
            }

            // Effect: whitelist the lockup contract.
            _lockupWhitelists[lockups[i]] = true;

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
        rewardsPerTokenScaled = _pools[poolId].rewardsDistributedPerTokenScaled;

        // Get the rewards distributed since the last snapshot.
        uint256 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(poolId);

        if (rewardsDistributedSinceLastSnapshot > 0) {
            // Get the rewards distributed per ERC20 token since the last snapshot, by scaling up.
            uint256 rewardsPerTokenSinceLastSnapshotScaled =
                rewardsDistributedSinceLastSnapshot.scaleUp() / _pools[poolId].totalStakedAmount;

            // Calculate the cumulative rewards distributed per ERC20 token.
            rewardsPerTokenScaled += rewardsPerTokenSinceLastSnapshotScaled;
        }

        return rewardsPerTokenScaled;
    }

    /// @notice Calculates the reward distributed per second without checking if the pool is active.
    function _rewardRate(uint256 poolId) private view returns (uint128) {
        // Safe to use `unchecked` because the following calculations cannot overflow.
        unchecked {
            // Calculate the reward period.
            uint40 rewardPeriod = _pools[poolId].endTime - _pools[poolId].startTime;

            // Calculate the reward rate.
            return _pools[poolId].rewardAmount / rewardPeriod;
        }
    }

    /// @notice Calculates cumulative rewards distributed since the last snapshot.
    /// @dev Returns 0 if:
    ///  - The total amount staked is 0.
    ///  - The start time is in the future.
    ///  - The last time update is greater than or equal to the end time.
    function _rewardsDistributedSinceLastSnapshot(uint256 poolId) private view returns (uint128 rewardsDistributed) {
        // If the total staked amount is 0, return 0.
        if (_pools[poolId].totalStakedAmount == 0) {
            return 0;
        }

        uint40 blockTimestamp = uint40(block.timestamp);
        uint40 poolEndTime = _pools[poolId].endTime;
        uint40 poolStartTime = _pools[poolId].startTime;

        // If the start time is in the future, return 0.
        if (blockTimestamp < poolStartTime) {
            return 0;
        }

        uint40 lastUpdateTime = _pools[poolId].lastUpdateTime;

        // If the last time update is greater than or equal to the end time, return 0.
        if (lastUpdateTime >= poolEndTime) {
            return 0;
        }

        // Define variables to store time range for rewards calculation.
        uint40 endingTimestamp;
        uint40 startingTimestamp;

        // If the last update time is less than the start time, the starting timestamp is the start time.
        if (lastUpdateTime <= poolStartTime) {
            startingTimestamp = poolStartTime;
        } else {
            startingTimestamp = lastUpdateTime;
        }

        // If the end time has passed, the ending timestamp is the pool end time.
        if (poolEndTime <= blockTimestamp) {
            endingTimestamp = poolEndTime;
        } else {
            endingTimestamp = blockTimestamp;
        }

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the elapsed time and the total reward period.
            uint256 elapsedTime = endingTimestamp - startingTimestamp;
            uint256 rewardsPeriod = poolEndTime - poolStartTime;

            // Calculate the total rewards distributed since the last snapshot.
            rewardsDistributed = ((_pools[poolId].rewardAmount * elapsedTime) / rewardsPeriod).toUint128();
        }

        return rewardsDistributed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Private function to update the global rewards.
    function _updateGlobalRewards(uint256 poolId) private returns (uint256 rewardsPerTokenScaled) {
        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(poolId);

        // Effect: update the rewards distributed per ERC20 token.
        _pools[poolId].rewardsDistributedPerTokenScaled = rewardsPerTokenScaled;

        // Effect: update the last time update.
        _pools[poolId].lastUpdateTime = uint40(block.timestamp);
    }

    /// @notice Update rewards data for the specified pool and user.
    function _updateRewards(uint256 poolId, address user) private {
        // Update the global rewards.
        uint256 rewardsPerTokenScaled = _updateGlobalRewards(poolId);

        // Update the user rewards.
        uint128 userRewards = _updateUserRewards(poolId, user, rewardsPerTokenScaled);

        // Log the event.
        emit UpdateRewards({
            poolId: poolId,
            lastUpdateTime: uint40(block.timestamp),
            rewardsDistributedPerTokenScaled: rewardsPerTokenScaled,
            user: user,
            pendingRewards: userRewards
        });
    }

    /// @dev Private function to update the user rewards.
    function _updateUserRewards(
        uint256 poolId,
        address user,
        uint256 rewardsPerTokenScaled
    )
        private
        returns (uint128)
    {
        // Load the struct.
        UserAccount storage userAccount = _userAccounts[user][poolId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userAccount.directAmountStaked + userAccount.streamAmountStaked;

        // If the user has tokens staked, update the user rewards earned.
        if (userTotalAmountStaked > 0) {
            // Compute the rewards earned per ERC20 token by the user since the previous snapshot.
            uint256 userRewardsPerTokenSinceLastSnapshotScaled =
                rewardsPerTokenScaled - userAccount.rewardsEarnedPerTokenScaled;

            // Compute the new rewards earned by the user since the last snapshot.
            uint256 userRewardsSinceLastSnapshotScaled =
                userRewardsPerTokenSinceLastSnapshotScaled * userTotalAmountStaked;

            // Scale down the rewards earned by the user since the last snapshot.
            uint128 userRewardsSinceLastSnapshot = userRewardsSinceLastSnapshotScaled.scaleDown().toUint128();

            // Effect: update the rewards earned by the user.
            userAccount.pendingRewards += userRewardsSinceLastSnapshot;
        }

        // Effect: update the rewards earned per ERC20 token by the user.
        userAccount.rewardsEarnedPerTokenScaled = rewardsPerTokenScaled;

        // Return the user's total rewards.
        return userAccount.pendingRewards;
    }
}
