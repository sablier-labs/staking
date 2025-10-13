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
            uint256 rptDistributedScaled = _rptDistributedScaled(poolId);

            // Calculate the rewards earned per ERC20 token by the user since the last snapshot.
            uint256 userRptSinceLastSnapshotScaled = rptDistributedScaled - userAccount.snapshotRptEarnedScaled;

            // Calculate the rewards earned by the user since the last snapshot.
            uint256 rewardsEarnedScaled = userRptSinceLastSnapshotScaled * userTotalAmountStaked;

            // Scale down the amount.
            rewardsEarnedSinceLastSnapshot = rewardsEarnedScaled.scaleDown().toUint128();
        }

        return userAccount.snapshotRewards + rewardsEarnedSinceLastSnapshot;
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
        revert Errors.SablierStaking_WithdrawNotAllowed(streamId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRate(uint256 poolId) external view override notNull(poolId) returns (uint128) {
        // Check: the pool is active.
        if (!_isActive(poolId)) {
            revert Errors.SablierStaking_PoolNotActive(poolId);
        }

        return _rewardRate(poolId);
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
        uint256 rewardsDistributedSinceLastSnapshotScaled = _rewardsDistributedSinceLastSnapshotScaled(poolId);

        // If the rewards distributed since the last snapshot is zero, return 0.
        if (rewardsDistributedSinceLastSnapshotScaled == 0) {
            return 0;
        }

        // Else, calculate it. Safe casting because rewards distributed is guaranteed to be less than 2^128.
        return uint128((rewardsDistributedSinceLastSnapshotScaled / _pools[poolId].totalStakedAmount).scaleDown());
    }

    /// @inheritdoc ISablierStaking
    function rewardsSinceLastSnapshot(uint256 poolId) external view override notNull(poolId) returns (uint128) {
        // Safe casting because rewards distributed is guaranteed to be less than 2^128.
        return uint128(_rewardsDistributedSinceLastSnapshotScaled(poolId).scaleDown());
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

        // Effect: snapshot rewards for `msg.sender`.
        _snapshotRewards(poolId, msg.sender);

        // Load rewards from storage.
        rewardsClaimed = _userAccounts[msg.sender][poolId].snapshotRewards;

        // Check: `msg.sender` has rewards to claim.
        if (rewardsClaimed == 0) {
            revert Errors.SablierStaking_ZeroClaimableRewards(poolId, msg.sender);
        }

        // Effect: set the rewards to 0.
        _userAccounts[msg.sender][poolId].snapshotRewards = 0;

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
        // Read the pool from storage using storage pointer.
        Pool storage pool = _pools[poolId];

        // Check: `msg.sender` is the pool admin.
        if (msg.sender != pool.admin) {
            revert Errors.SablierStaking_CallerNotPoolAdmin(poolId, msg.sender, pool.admin);
        }

        // Check: pool end time is in the past.
        if (pool.endTime >= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInPast(poolId, pool.endTime);
        }

        // Checks: validate the timestamps and reward amount.
        newStartTime = _checkTimestampsAndRewardAmount(newStartTime, newEndTime, newRewardAmount);

        // Calculate the buffer amount.
        uint128 bufferAmount = type(uint128).max - pool.cumulativeRewardAmount;

        // Check: new reward amount does not exceed the buffer amount.
        if (newRewardAmount > bufferAmount) {
            revert Errors.SablierStaking_CumulativeRewardAmountOverflow({
                newRewardAmount: newRewardAmount,
                remainingBufferAmount: bufferAmount
            });
        }

        // Safe to use `unchecked` because cumulative reward amount can not overflow as we checked the overflow above.
        unchecked {
            // Effect: update the cumulative reward amount.
            pool.cumulativeRewardAmount += newRewardAmount;
        }

        // Effect: snapshot the global rewards.
        _snapshotGlobalRewards(poolId);

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

        // Check: staking token is not the zero address.
        if (address(stakingToken) == address(0)) {
            revert Errors.SablierStaking_StakingTokenZeroAddress();
        }

        // Checks: validate the timestamps and reward amount.
        startTime = _checkTimestampsAndRewardAmount(startTime, endTime, rewardAmount);

        // Load the next Pool ID from storage.
        poolId = nextPoolId;

        // Effect: store the pool parameters in the storage.
        _pools[poolId] = Pool({
            admin: admin,
            cumulativeRewardAmount: rewardAmount,
            endTime: endTime,
            rewardAmount: rewardAmount,
            rewardToken: rewardToken,
            snapshotRptDistributedScaled: 0,
            snapshotTime: 0,
            stakingToken: stakingToken,
            startTime: startTime,
            totalStakedAmount: 0
        });

        // Safe to use `unchecked` because it can't overflow.
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
        // Cast `msg.sender` as the Lockup NFT.
        ISablierLockupNFT msgSenderAsLockup = ISablierLockupNFT(msg.sender);

        // Get the Pool ID in which the stream ID is staked.
        uint256 poolId = _streamsLookup[msgSenderAsLockup][streamId].poolId;

        // Return the selector if the stream ID is not staked.
        if (poolId == 0) {
            return ISablierLockupRecipient.onSablierLockupCancel.selector;
        }

        // Load the storage in memory.
        address owner = _streamsLookup[msgSenderAsLockup][streamId].owner;
        uint128 streamAmountStaked = _userAccounts[owner][poolId].streamAmountStaked;

        // Checks and Effects: unstake the `senderAmount` for the user.
        _unstake({ poolId: poolId, unstakeAmount: senderAmount, maxAllowed: streamAmountStaked, user: owner });

        // Safe to use `unchecked` because `_unstake` verifies that `senderAmount` does not exceed `streamAmountStaked`.
        unchecked {
            // Effect: decrease the user's stream amount staked.
            _userAccounts[owner][poolId].streamAmountStaked = streamAmountStaked - senderAmount;
        }

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20Token(uint256 poolId, uint128 amount) external override noDelegateCall notNull(poolId) {
        // Checks and Effects: stake the amount.
        _stake(poolId, amount);

        // Safe to use `unchecked` because it would first overflow in `_stake`.
        unchecked {
            // Effect: update direct amount staked by `msg.sender`.
            _userAccounts[msg.sender][poolId].directAmountStaked += amount;
        }

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
        if (!_whitelistedLockups[lockup]) {
            revert Errors.SablierStaking_LockupNotWhitelisted(lockup);
        }

        // Get the stream's underlying token.
        IERC20 underlyingToken = _getUnderlyingToken(lockup, streamId);

        // Check: the underlying token is the same as the pool's staking token.
        if (underlyingToken != _pools[poolId].stakingToken) {
            revert Errors.SablierStaking_UnderlyingTokenDifferent(underlyingToken, _pools[poolId].stakingToken);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Checks and Effects: stake the amount.
        _stake(poolId, amountInStream);

        // Safe to use `unchecked` because it would first overflow in `_stake`.
        unchecked {
            // Effect: update stream amount staked by `msg.sender`.
            _userAccounts[msg.sender][poolId].streamAmountStaked += amountInStream;
        }

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

        uint128 directAmountStaked = _userAccounts[msg.sender][poolId].directAmountStaked;

        // Checks and Effects: unstake the `amount` for the user.
        _unstake({ poolId: poolId, unstakeAmount: amount, maxAllowed: directAmountStaked, user: msg.sender });

        // Safe to use `unchecked` because `_unstake` verifies that `amount` does not exceed `directAmountStaked`.
        unchecked {
            // Effect: decrease direct amount staked by `msg.sender`.
            _userAccounts[msg.sender][poolId].directAmountStaked = directAmountStaked - amount;
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

        uint128 streamAmountStaked = _userAccounts[msg.sender][poolId].streamAmountStaked;

        // Checks and Effects: unstake the `amountInStream` for the user.
        _unstake({ poolId: poolId, unstakeAmount: amountInStream, maxAllowed: streamAmountStaked, user: msg.sender });

        // Safe to use `unchecked` because `_unstake` verifies that `amountInStream` does not exceed
        // `streamAmountStaked`.
        unchecked {
            // Effect: decrease stream amount staked by `msg.sender`.
            _userAccounts[msg.sender][poolId].streamAmountStaked = streamAmountStaked - amountInStream;
        }

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
            ISablierLockupNFT lockup = lockups[i];

            // Check: the lockup contract is not already whitelisted.
            if (_whitelistedLockups[lockup]) {
                revert Errors.SablierStaking_LockupAlreadyWhitelisted(lockup);
            }

            // Check: the lockup contract supports {ISablierLockupNFT} interface.
            _hasRequiredInterface(lockup);

            // Check: the lockup contract returns `true` when `isAllowedToHook` is called.
            if (!lockup.isAllowedToHook(address(this))) {
                revert Errors.SablierStaking_UnsupportedOnAllowedToHook(lockup);
            }

            // Effect: whitelist the lockup contract.
            _whitelistedLockups[lockup] = true;

            // Log the event.
            emit LockupWhitelisted(address(comptroller), lockup);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Snapshot rewards data for the specified pool and user.
    function _snapshotRewards(uint256 poolId, address user) internal {
        // Snapshot the global rewards.
        uint256 rptDistributedScaled = _snapshotGlobalRewards(poolId);

        // Snapshot the user rewards.
        uint128 userRewards = _snapshotUserRewards(poolId, user, rptDistributedScaled);

        // Log the event.
        emit SnapshotRewards({
            poolId: poolId,
            snapshotTime: uint40(block.timestamp),
            snapshotRptDistributedScaled: rptDistributedScaled,
            user: user,
            userRewards: userRewards
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Common checks between `createPool` and `configureNextRound`.
    function _checkTimestampsAndRewardAmount(
        uint40 startTime,
        uint40 endTime,
        uint128 rewardAmount
    )
        private
        view
        returns (uint40)
    {
        uint40 blockTimestamp = uint40(block.timestamp);

        // Zero is a sentinel value for `block.timestamp`.
        if (startTime == 0) {
            startTime = blockTimestamp;
        }
        // Otherwise, check the start time is not in the past.
        else if (startTime < blockTimestamp) {
            revert Errors.SablierStaking_StartTimeInPast(startTime);
        }

        // Check: start time is less than end time.
        if (endTime <= startTime) {
            revert Errors.SablierStaking_StartTimeNotLessThanEndTime(startTime, endTime);
        }

        // Check: reward amount is not zero.
        if (rewardAmount == 0) {
            revert Errors.SablierStaking_RewardAmountZero();
        }

        // Return the start time in case the sentinel value was used.
        return startTime;
    }

    /// @notice Retrieves the token being streamed in the specified stream ID.
    function _getUnderlyingToken(ISablierLockupNFT lockup, uint256 streamId) private view returns (IERC20 token) {
        // Since, Lockup v1.2 does not implement `getUnderlyingToken`, low-level call is used to call this function. If
        // the call fails, `getAsset` will be called as a fallback.
        (bool success, bytes memory data) =
            address(lockup).staticcall(abi.encodeCall(ISablierLockupNFT.getUnderlyingToken, (streamId)));

        if (!success) {
            (, data) = address(lockup).staticcall(abi.encodeCall(ISablierLockupNFT.getAsset, (streamId)));
        }

        // Since only whitelisted Lockup contracts are allowed to stake, it is safe to assume that the returned data is
        // a valid ERC20 token.
        token = abi.decode(data, (IERC20));
    }

    /// @notice Check if the lockup contract implements the functions from {ISablierLockupNFT}.
    function _hasRequiredInterface(ISablierLockupNFT lockup) private view {
        // It is assumed that at least one stream exists in the lockup contract.
        uint256 testStreamId = 1;

        uint256 amountsSelectorsCount = 3;

        bytes4[] memory getAmountSelectors = new bytes4[](amountsSelectorsCount);
        getAmountSelectors[0] = ISablierLockupNFT.getDepositedAmount.selector;
        getAmountSelectors[1] = ISablierLockupNFT.getWithdrawnAmount.selector;
        getAmountSelectors[2] = ISablierLockupNFT.getRefundedAmount.selector;

        for (uint256 i = 0; i < amountsSelectorsCount; ++i) {
            // Use a low-level call to check if the function is implemented.
            (bool success,) = address(lockup).staticcall(abi.encodeWithSelector(getAmountSelectors[i], testStreamId));
            if (!success) {
                revert Errors.SablierStaking_LockupMissesSelector(lockup, getAmountSelectors[i]);
            }
        }

        // Use a low-level call to check if the function is implemented.
        (bool successGetUnderlyingToken,) = address(lockup).staticcall(
            abi.encodeWithSelector(ISablierLockupNFT.getUnderlyingToken.selector, testStreamId)
        );

        // If `getUnderlyingToken` is not implemented, check `getAsset` is implemented.
        if (!successGetUnderlyingToken) {
            (bool successGetAsset,) =
                address(lockup).staticcall(abi.encodeWithSelector(ISablierLockupNFT.getAsset.selector, testStreamId));

            // Revert if `getAsset` is not implemented.
            if (!successGetAsset) {
                revert Errors.SablierStaking_LockupMissesSelector(lockup, ISablierLockupNFT.getAsset.selector);
            }
        }
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

    /// @notice Calculates cumulative rewards distributed scaled since the last snapshot.
    /// @dev Returns 0 if:
    ///  - The total amount staked is 0.
    ///  - The start time is in the future.
    ///  - The snapshot time is greater than or equal to the end time.
    function _rewardsDistributedSinceLastSnapshotScaled(uint256 poolId)
        private
        view
        returns (uint256 rewardsDistributedScaled)
    {
        // Read the pool from storage using storage pointer.
        Pool storage pool = _pools[poolId];

        // If the total staked amount is 0, return 0.
        if (pool.totalStakedAmount == 0) {
            return 0;
        }

        uint256 blockTimestamp = block.timestamp;
        uint256 poolEndTime = uint256(pool.endTime);
        uint256 poolStartTime = uint256(pool.startTime);

        // If the pool start time is not in the past, return 0.
        if (blockTimestamp <= poolStartTime) {
            return 0;
        }

        uint256 snapshotTime = uint256(pool.snapshotTime);

        // If the snapshot time is greater than or equal to the end time, return 0.
        if (snapshotTime >= poolEndTime) {
            return 0;
        }

        // If the snapshot time is less than the start time, the starting timestamp is the start time.
        uint256 startingTimestamp = snapshotTime <= poolStartTime ? poolStartTime : snapshotTime;

        // If the end time has passed, the ending timestamp is the pool end time.
        uint256 endingTimestamp = poolEndTime <= blockTimestamp ? poolEndTime : blockTimestamp;

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the elapsed time and the total reward period.
            uint256 elapsedTime = endingTimestamp - startingTimestamp;
            uint256 rewardsPeriod = poolEndTime - poolStartTime;

            // Calculate the total rewards distributed since the last snapshot.
            rewardsDistributedScaled = (pool.rewardAmount * elapsedTime).scaleUp() / rewardsPeriod;
        }

        return rewardsDistributedScaled;
    }

    /// @dev Calculates the latest cumulative rewards distributed per ERC20 token.
    function _rptDistributedScaled(uint256 poolId) private view returns (uint256 rptDistributedScaled) {
        rptDistributedScaled = _pools[poolId].snapshotRptDistributedScaled;

        // Get the rewards distributed scaled since the last snapshot.
        uint256 rewardsDistributedSinceLastSnapshotScaled = _rewardsDistributedSinceLastSnapshotScaled(poolId);

        if (rewardsDistributedSinceLastSnapshotScaled > 0) {
            // Get the rewards distributed per ERC20 token since the last snapshot.
            uint256 rptSinceLastSnapshotScaled =
                rewardsDistributedSinceLastSnapshotScaled / _pools[poolId].totalStakedAmount;

            // Calculate the cumulative rewards distributed per ERC20 token.
            rptDistributedScaled += rptSinceLastSnapshotScaled;
        }

        return rptDistributedScaled;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Private function to snapshot the global rewards.
    function _snapshotGlobalRewards(uint256 poolId) private returns (uint256 rptDistributedScaled) {
        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        rptDistributedScaled = _rptDistributedScaled(poolId);

        // Effect: snapshot the rewards distributed per ERC20 token.
        _pools[poolId].snapshotRptDistributedScaled = rptDistributedScaled;

        // Effect: update the snapshot time.
        _pools[poolId].snapshotTime = uint40(block.timestamp);
    }

    /// @dev Private function to snapshot the user rewards.
    function _snapshotUserRewards(
        uint256 poolId,
        address user,
        uint256 rptDistributedScaled
    )
        private
        returns (uint128 userRewards)
    {
        // Load the struct.
        UserAccount storage userAccount = _userAccounts[user][poolId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userAccount.directAmountStaked + userAccount.streamAmountStaked;

        userRewards = userAccount.snapshotRewards;

        // If the user has tokens staked, update the user rewards earned.
        if (userTotalAmountStaked > 0) {
            // Compute the rewards earned per ERC20 token by the user since the previous snapshot.
            uint256 userRptSinceLastSnapshotScaled = rptDistributedScaled - userAccount.snapshotRptEarnedScaled;

            // Compute the new rewards earned by the user since the last snapshot.
            uint256 userRewardsSinceLastSnapshotScaled = userRptSinceLastSnapshotScaled * userTotalAmountStaked;

            // Scale down the rewards earned by the user since the last snapshot.
            uint128 userRewardsSinceLastSnapshot = userRewardsSinceLastSnapshotScaled.scaleDown().toUint128();

            userRewards += userRewardsSinceLastSnapshot;

            // Effect: snapshot the rewards earned by the user.
            userAccount.snapshotRewards = userRewards;
        }

        // Effect: snapshot the rewards earned per ERC20 token by the user.
        userAccount.snapshotRptEarnedScaled = rptDistributedScaled;
    }

    /// @dev Common logic between stake functions.
    function _stake(uint256 poolId, uint128 amount) private {
        // Check: the end time is in the future.
        if (_pools[poolId].endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_EndTimeNotInFuture(poolId, _pools[poolId].endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_StakingZeroAmount(poolId);
        }

        // Effect: snapshot rewards for `msg.sender`.
        _snapshotRewards(poolId, msg.sender);

        // Effect: update total staked amount in the pool.
        _pools[poolId].totalStakedAmount += amount;
    }

    /// @dev Common logic between unstake functions.
    function _unstake(uint256 poolId, uint128 unstakeAmount, uint128 maxAllowed, address user) private {
        // Check: unstake amount is not greater than the user's staked amount.
        if (unstakeAmount > maxAllowed) {
            revert Errors.SablierStaking_Overflow(poolId, unstakeAmount, maxAllowed);
        }

        // Effect: snapshot rewards for user.
        _snapshotRewards(poolId, user);

        // Safe to use `unchecked` because `unstakeAmount` is checked above.
        unchecked {
            // Effect: decrease total staked amount in the pool.
            _pools[poolId].totalStakedAmount -= unstakeAmount;
        }
    }
}
