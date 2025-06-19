// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { NoDelegateCall } from "@sablier/evm-utils/src/NoDelegateCall.sol";
import { RoleAdminable } from "@sablier/evm-utils/src/RoleAdminable.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { SablierStakingState } from "./abstracts/SablierStakingState.sol";
import { ISablierLockupNFT } from "./interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "./interfaces/ISablierStaking.sol";
import { Errors } from "./libraries/Errors.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { Campaign, GlobalSnapshot, StreamLookup, UserShares, UserSnapshot } from "./types/DataTypes.sol";

/// @title SablierStaking
/// @notice See the documentation in {ISablierStaking}.
contract SablierStaking is
    ERC721Holder, // 1 inherited component
    ISablierStaking, // 5 inherited components
    NoDelegateCall, // 0 inherited components
    RoleAdminable, // 3 inherited components
    SablierStakingState // 1 inherited component
{
    using Helpers for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(address initialAdmin) RoleAdminable(initialAdmin) {
        // Effect: Set the next campaign ID to 1.
        nextCampaignId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function getClaimableRewards(
        uint256 campaignId,
        address user
    )
        external
        view
        notNull(campaignId)
        notCanceled(campaignId)
        returns (uint128)
    {
        // Check: the user address is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStaking_UserZeroAddress();
        }

        uint128 rewardsEarnedSinceLastSnapshot = _userRewardsSinceLastSnapshot(campaignId, user);

        return _userSnapshot[user][campaignId].rewards + rewardsEarnedSinceLastSnapshot;
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

        // Get the campaign ID in which the stream ID is staked.
        uint256 campaignId = _streamLookup[lockup][streamId].campaignId;

        // Check: the campaign ID is not zero.
        if (campaignId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        revert Errors.SablierStaking_WithdrawNotAllowed(campaignId, lockup, streamId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRate(uint256 campaignId)
        external
        view
        override
        notNull(campaignId)
        isActive(campaignId)
        returns (uint128)
    {
        // If the total amount staked is zero, return 0.
        if (_totalAmountStaked[campaignId] == 0) {
            return 0;
        }

        return _rewardRate(campaignId);
    }

    /// @inheritdoc ISablierStaking
    function rewardRatePerTokenStaked(uint256 campaignId)
        external
        view
        override
        notNull(campaignId)
        isActive(campaignId)
        returns (uint128)
    {
        uint128 totalAmountStaked = _totalAmountStaked[campaignId];

        // If the total amount staked is zero, return 0.
        if (totalAmountStaked == 0) {
            return 0;
        }

        uint128 rewardPerSecond = _rewardRate(campaignId);

        // Calculate the reward distributed per second.
        return rewardPerSecond / totalAmountStaked;
    }

    /// @inheritdoc ISablierStaking
    function rewardsPerTokenSinceLastSnapshot(uint256 campaignId)
        external
        view
        override
        notNull(campaignId)
        notCanceled(campaignId)
        returns (uint128)
    {
        // Check: the campaign start time is not in the future.
        if (_campaign[campaignId].startTime > uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignNotStarted(campaignId, _campaign[campaignId].startTime);
        }

        // Get the rewards distributed since the last snapshot.
        uint128 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(campaignId);

        // If the rewards distributed since the last snapshot is zero, return 0.
        if (rewardsDistributedSinceLastSnapshot == 0) {
            return 0;
        }

        // Else, calculate it.
        return rewardsDistributedSinceLastSnapshot / _totalAmountStaked[campaignId];
    }

    /// @inheritdoc ISablierStaking
    function rewardsSinceLastSnapshot(uint256 campaignId)
        external
        view
        override
        notNull(campaignId)
        notCanceled(campaignId)
        returns (uint128)
    {
        // Check: the campaign start time is not in the future.
        if (_campaign[campaignId].startTime > uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignNotStarted(campaignId, _campaign[campaignId].startTime);
        }

        return _rewardsDistributedSinceLastSnapshot(campaignId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(ISablierLockupRecipient).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER-FACING STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function cancelCampaign(uint256 campaignId)
        external
        override
        noDelegateCall
        notNull(campaignId)
        notCanceled(campaignId)
        returns (uint128 amountRefunded)
    {
        // Load the campaign from storage.
        Campaign memory campaign = _campaign[campaignId];

        // Check: `msg.sender` is the campaign admin.
        if (msg.sender != campaign.admin) {
            revert Errors.SablierStaking_CallerNotCampaignAdmin(campaignId, msg.sender, campaign.admin);
        }

        // Check: the campaign start time is in the future.
        if (campaign.startTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignAlreadyStarted(campaignId, campaign.startTime);
        }

        // Effect: set the campaign as canceled.
        _campaign[campaignId].wasCanceled = true;

        // Interaction: refund the reward tokens to the campaign admin.
        amountRefunded = campaign.totalRewards;
        campaign.rewardToken.safeTransfer({ to: msg.sender, value: amountRefunded });

        // Log the event.
        emit CancelCampaign(campaignId);
    }

    /// @inheritdoc ISablierStaking
    function claimRewards(uint256 campaignId)
        external
        override
        noDelegateCall
        notNull(campaignId)
        notCanceled(campaignId)
        returns (uint128 rewards)
    {
        // Check: the current timestamp is greater than or equal to the campaign start time.
        if (block.timestamp < _campaign[campaignId].startTime) {
            revert Errors.SablierStaking_CampaignNotStarted(campaignId, _campaign[campaignId].startTime);
        }

        // Effect: snapshot rewards data to the latest values.
        _snapshotRewards(campaignId, msg.sender);

        // Load rewards from storage.
        rewards = _userSnapshot[msg.sender][campaignId].rewards;

        // Check: `msg.sender` has rewards to claim.
        if (rewards == 0) {
            revert Errors.SablierStaking_ZeroClaimableRewards(campaignId, msg.sender);
        }

        // Effect: set the rewards to 0.
        _userSnapshot[msg.sender][campaignId].rewards = 0;

        // Effect: update the last update time.
        _userSnapshot[msg.sender][campaignId].lastUpdateTime = uint40(block.timestamp);

        // Interaction: transfer the reward to `msg.sender`.
        IERC20 rewardToken = _campaign[campaignId].rewardToken;
        rewardToken.safeTransfer({ to: msg.sender, value: rewards });

        // Log the event.
        emit ClaimRewards(campaignId, msg.sender, rewards);
    }

    /// @inheritdoc ISablierStaking
    function createCampaign(
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
        returns (uint256 campaignId)
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

        // Load the next campaign ID from storage.
        campaignId = nextCampaignId;

        // Effect: store the campaign in the storage.
        _campaign[campaignId] = Campaign({
            admin: admin,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: totalRewards,
            wasCanceled: false
        });

        // Safe to use unchecked because it can't overflow.
        unchecked {
            // Effect: bump the next campaign ID.
            nextCampaignId = campaignId + 1;
        }

        // Interaction: transfer the rewards from the `msg.sender` to this contract.
        rewardToken.safeTransferFrom({ from: msg.sender, to: address(this), value: totalRewards });

        // Log the event.
        emit CreateCampaign(campaignId, admin, stakingToken, rewardToken, startTime, endTime, totalRewards);
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

        // Get the campaign ID in which the stream ID is staked.
        uint256 campaignId = streamLookup.campaignId;

        // Check: the campaign ID is not zero.
        if (campaignId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(ISablierLockupNFT(msg.sender), streamId);
        }

        // Get the owner of the stream.
        address owner = streamLookup.owner;

        // Effect: snapshot user rewards.
        _snapshotRewards(campaignId, owner);

        // Effect: decrease the total amount staked in the campaign.
        _totalAmountStaked[campaignId] -= senderAmount;

        // Effect: decrease the user's share of stream amount staked.
        _userShares[owner][campaignId].streamAmountStaked -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @inheritdoc ISablierStaking
    function snapshotRewards(
        uint256 campaignId,
        address user
    )
        external
        override
        noDelegateCall
        notNull(campaignId)
        notCanceled(campaignId)
    {
        // Get the user shares.
        UserShares memory userShares = _userShares[user][campaignId];

        // Check: the total amount staked by user is not zero.
        if (userShares.directAmountStaked + userShares.streamAmountStaked == 0) {
            revert Errors.SablierStaking_NoStakedAmount(campaignId, user);
        }

        uint40 lastUpdateTime = _userSnapshot[user][campaignId].lastUpdateTime;

        // Check: the last update time is less than the campaign end time.
        if (lastUpdateTime >= _campaign[campaignId].endTime) {
            revert Errors.SablierStaking_SnapshotNotAllowed(campaignId, user, lastUpdateTime);
        }

        // Effect: snapshot rewards data to the latest values for `user`.
        _snapshotRewards(campaignId, user);
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20Token(
        uint256 campaignId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(campaignId)
        notCanceled(campaignId)
    {
        // Retrieve the campaign from storage.
        Campaign memory campaign = _campaign[campaignId];

        // Check: the campaign end time is in the future.
        if (campaign.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignHasEnded(campaignId, campaign.endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_StakingZeroAmount(campaignId);
        }

        // Effect: update rewards for `msg.sender`.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: update total amount staked in the campaign.
        _totalAmountStaked[campaignId] += amount;

        // Effect: update direct amount staked by `msg.sender`.
        _userShares[msg.sender][campaignId].directAmountStaked += amount;

        // Interaction: transfer the tokens from the `msg.sender` to this contract.
        campaign.stakingToken.safeTransferFrom({ from: msg.sender, to: address(this), value: amount });

        // Log the event.
        emit StakeERC20Token(campaignId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function stakeLockupNFT(
        uint256 campaignId,
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        override
        noDelegateCall
        notNull(campaignId)
        notCanceled(campaignId)
    {
        // Check: the lockup is whitelisted.
        if (!_lockupWhitelist[lockup]) {
            revert Errors.SablierStaking_LockupNotWhitelisted(lockup);
        }

        // Retrieve the campaign from storage.
        Campaign memory campaign = _campaign[campaignId];

        // Check: the campaign end time is in the future.
        if (campaign.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignHasEnded(campaignId, campaign.endTime);
        }

        // Check: the stream's underlying token is the same as the campaign's staking token.
        IERC20 underlyingToken = lockup.getUnderlyingToken(streamId);
        if (underlyingToken != campaign.stakingToken) {
            revert Errors.SablierStaking_UnderlyingTokenDifferent(underlyingToken, campaign.stakingToken);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = Helpers.amountInStream(lockup, streamId);

        // Check: the amount in stream is not zero, i.e. the stream is not depleted.
        if (amountInStream == 0) {
            revert Errors.SablierStaking_DepletedStream(lockup, streamId);
        }

        // Effect: update rewards.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: update total amount staked in the campaign.
        _totalAmountStaked[campaignId] += amountInStream;

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][campaignId];

        // Effect: update stream amount staked by `msg.sender`.
        _userShares[msg.sender][campaignId].streamAmountStaked = userShares.streamAmountStaked + amountInStream;

        // Effect: update the number of streams staked by `msg.sender`.
        _userShares[msg.sender][campaignId].streamsCount = userShares.streamsCount + 1;

        // Effect: update the `StreamLookup` mapping.
        _streamLookup[lockup][streamId] = StreamLookup({ campaignId: campaignId, owner: msg.sender });

        // Interaction: transfer the Lockup stream from the `msg.sender` to this contract.
        lockup.safeTransferFrom({ from: msg.sender, to: address(this), tokenId: streamId });

        // Log the event.
        emit StakeLockupNFT(campaignId, msg.sender, lockup, streamId, amountInStream);
    }

    /// @inheritdoc ISablierStaking
    function unstakeERC20Token(
        uint256 campaignId,
        uint128 amount
    )
        external
        override
        noDelegateCall
        notNull(campaignId)
    {
        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_UnstakingZeroAmount(campaignId);
        }

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][campaignId];

        // Check: `amount` is not greater than the direct amount staked.
        if (amount > userShares.directAmountStaked) {
            revert Errors.SablierStaking_AmountExceedsStakedAmount(campaignId, amount, userShares.directAmountStaked);
        }

        // Snapshot rewards if the campaign is not canceled.
        if (!_campaign[campaignId].wasCanceled) {
            // Effect: update rewards.
            _snapshotRewards(campaignId, msg.sender);
        }
        // Otherwise, update the last update time only.
        else {
            // Effect: update the last update time.
            _globalSnapshot[campaignId].lastUpdateTime = uint40(block.timestamp);
            _userSnapshot[msg.sender][campaignId].lastUpdateTime = uint40(block.timestamp);
        }

        // Effect: update the global last update time.
        _globalSnapshot[campaignId].lastUpdateTime = uint40(block.timestamp);

        // Effect: reduce direct amount staked by `msg.sender`.
        _userShares[msg.sender][campaignId].directAmountStaked = userShares.directAmountStaked - amount;

        // Interaction: transfer the tokens to `msg.sender`.
        _campaign[campaignId].stakingToken.safeTransfer({ to: msg.sender, value: amount });

        // Log the event.
        emit UnstakeERC20Token(campaignId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external override noDelegateCall {
        StreamLookup memory streamLookup = _streamLookup[lockup][streamId];

        // Get the campaign ID in which the stream ID is staked.
        uint256 campaignId = streamLookup.campaignId;

        // Check: the campaign ID is not zero.
        if (campaignId == 0) {
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

        // Snapshot rewards if the campaign is not canceled.
        if (!_campaign[campaignId].wasCanceled) {
            // Effect: update rewards.
            _snapshotRewards(campaignId, msg.sender);
        }
        // Otherwise, update the last update time only.
        else {
            // Effect: update the last update time.
            _globalSnapshot[campaignId].lastUpdateTime = uint40(block.timestamp);
            _userSnapshot[msg.sender][campaignId].lastUpdateTime = uint40(block.timestamp);
        }

        // Effect: reduce total amount staked in the campaign.
        _totalAmountStaked[campaignId] -= amountInStream;

        // Retrieve the user shares from storage.
        UserShares memory userShares = _userShares[msg.sender][campaignId];

        // Effect: reduce stream amount staked by `msg.sender`.
        _userShares[msg.sender][campaignId].streamAmountStaked = userShares.streamAmountStaked - amountInStream;

        // Effect: reduce the number of streams staked by `msg.sender`.
        _userShares[msg.sender][campaignId].streamsCount = userShares.streamsCount - 1;

        // Effect: delete the `StreamLookup` mapping.
        delete _streamLookup[lockup][streamId];

        // Interaction: transfer the Lockup stream to `msg.sender`.
        lockup.safeTransferFrom({ from: address(this), to: msg.sender, tokenId: streamId });

        // Log the event.
        emit UnstakeLockupNFT(campaignId, msg.sender, lockup, streamId);
    }

    /// @inheritdoc ISablierStaking
    function whitelistLockups(ISablierLockupNFT[] calldata lockups)
        external
        override
        noDelegateCall
        onlyRole(LOCKUP_WHITELIST_ROLE)
    {
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
            emit LockupWhitelisted(lockups[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculates the latest cumulative rewards distributed per ERC20 token.
    function _latestRewardsDistributedPerTokenScaled(uint256 campaignId)
        private
        view
        returns (uint256 rewardsPerTokenScaled)
    {
        // Load the global snapshot into memory.
        GlobalSnapshot memory globalSnapshot = _globalSnapshot[campaignId];

        rewardsPerTokenScaled = globalSnapshot.rewardsDistributedPerTokenScaled;

        // Get the rewards distributed since the last snapshot.
        uint256 rewardsDistributedSinceLastSnapshot = _rewardsDistributedSinceLastSnapshot(campaignId);

        if (rewardsDistributedSinceLastSnapshot > 0) {
            // Get the rewards distributed per ERC20 token since the last snapshot, by scaling up.
            uint256 rewardsPerTokenSinceLastSnapshotScaled =
                rewardsDistributedSinceLastSnapshot.scaleUp() / _totalAmountStaked[campaignId];

            // Calculate the cumulative rewards distributed per ERC20 token.
            rewardsPerTokenScaled += rewardsPerTokenSinceLastSnapshotScaled;
        }

        return rewardsPerTokenScaled;
    }

    /// @notice Calculates the reward distributed per second without checking if the campaign is active.
    function _rewardRate(uint256 campaignId) private view returns (uint128) {
        Campaign memory campaign = _campaign[campaignId];

        // Calculate the reward duration.
        uint40 rewardDuration = campaign.endTime - campaign.startTime;

        // Calculate the reward rate.
        return campaign.totalRewards / rewardDuration;
    }

    /// @notice Calculates cumulative rewards distributed since the last snapshot.
    /// @dev Returns 0 if:
    ///  - The total amount staked is 0.
    ///  - The campaign has not started.
    ///  - The last time update is greater than or equal to the campaign end time.
    function _rewardsDistributedSinceLastSnapshot(uint256 campaignId)
        private
        view
        returns (uint128 rewardsDistributed)
    {
        // If the total amount staked is 0, return 0.
        if (_totalAmountStaked[campaignId] == 0) {
            return 0;
        }

        Campaign memory campaign = _campaign[campaignId];

        // If the campaign has not started, return 0.
        if (uint40(block.timestamp) < campaign.startTime) {
            return 0;
        }

        uint40 lastUpdateTime = _globalSnapshot[campaignId].lastUpdateTime;

        // If the last time update is greater than or equal to the campaign end time, return 0.
        if (lastUpdateTime >= campaign.endTime) {
            return 0;
        }

        // Define variables to store time range for rewards calculation.
        uint40 endingTimestamp;
        uint40 startingTimestamp;

        // If the last update time is less than the start time, the starting timestamp is the campaign start time.
        if (lastUpdateTime <= campaign.startTime) {
            startingTimestamp = campaign.startTime;
        } else {
            startingTimestamp = lastUpdateTime;
        }

        // If the end time has passed, the ending timestamp is the campaign end time.
        if (campaign.endTime <= uint40(block.timestamp)) {
            endingTimestamp = campaign.endTime;
        } else {
            endingTimestamp = uint40(block.timestamp);
        }

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the elapsed time and the total campaign duration.
            uint256 elapsedTime = endingTimestamp - startingTimestamp;
            uint256 campaignDuration = campaign.endTime - campaign.startTime;

            // If elapsed time is equal to the campaign duration, return the total rewards.
            if (elapsedTime == campaignDuration) {
                return campaign.totalRewards;
            }

            // Calculate the total rewards distributed since the last snapshot.
            rewardsDistributed = ((campaign.totalRewards * elapsedTime) / campaignDuration).toUint128();
        }

        return rewardsDistributed;
    }

    /// @dev Calculates the rewards earned by the user since the last snapshot.
    function _userRewardsSinceLastSnapshot(uint256 campaignId, address user) private view returns (uint128) {
        UserShares memory userShares = _userShares[user][campaignId];

        // Calculate the total amount staked by the user.
        uint128 userTotalAmountStaked = userShares.directAmountStaked + userShares.streamAmountStaked;

        // If the user has no tokens staked, return 0.
        if (userTotalAmountStaked == 0) {
            return 0;
        }

        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        uint256 rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(campaignId);

        // Calculate the rewards earned per ERC20 token by the user since the last snapshot.
        uint256 userRewardsPerTokenSinceLastSnapshotScaled =
            rewardsPerTokenScaled - _userSnapshot[user][campaignId].rewardsEarnedPerTokenScaled;

        // Calculate the rewards earned by the user since the last snapshot.
        uint256 rewardsEarnedScaled = userRewardsPerTokenSinceLastSnapshotScaled * userTotalAmountStaked;

        // Return the scaled down amount.
        return rewardsEarnedScaled.scaleDown().toUint128();
    }

    /*//////////////////////////////////////////////////////////////////////////
                          PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Snapshots rewards data for the specified campaign and user.
    function _snapshotRewards(uint256 campaignId, address user) private {
        // Update the global snapshot.
        uint256 rewardsPerTokenScaled = _updateGlobalSnapshot(campaignId);

        // Update the user snapshot.
        uint128 userRewards = _updateUserSnapshot(campaignId, user, rewardsPerTokenScaled);

        // Log the event.
        emit SnapshotRewards({
            campaignId: campaignId,
            lastUpdateTime: uint40(block.timestamp),
            rewardsDistributedPerTokenScaled: rewardsPerTokenScaled,
            user: user,
            userRewards: userRewards
        });
    }

    /// @notice Private function to update the global snapshot.
    function _updateGlobalSnapshot(uint256 campaignId) private returns (uint256 rewardsPerTokenScaled) {
        // Get the latest value of the cumulative rewards distributed per ERC20 token.
        rewardsPerTokenScaled = _latestRewardsDistributedPerTokenScaled(campaignId);

        // Effect: update the rewards distributed per ERC20 token.
        _globalSnapshot[campaignId].rewardsDistributedPerTokenScaled = rewardsPerTokenScaled;

        // Effect: update the last time update.
        _globalSnapshot[campaignId].lastUpdateTime = uint40(block.timestamp);
    }

    /// @dev Private function to update the user snapshot.
    function _updateUserSnapshot(
        uint256 campaignId,
        address user,
        uint256 rewardsPerTokenScaled
    )
        private
        returns (uint128 userRewards)
    {
        UserSnapshot memory userSnapshot = _userSnapshot[user][campaignId];
        UserShares memory userShares = _userShares[user][campaignId];

        uint128 userTotalAmountStaked = userShares.directAmountStaked + userShares.streamAmountStaked;

        // Update the user snapshot if the last time update is less than the campaign end time.
        if (userSnapshot.lastUpdateTime < _campaign[campaignId].endTime) {
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
                _userSnapshot[user][campaignId].rewards = userRewards;
            }

            // Effect: update the rewards earned per ERC20 token by the user.
            _userSnapshot[user][campaignId].rewardsEarnedPerTokenScaled = rewardsPerTokenScaled;

            // Effect: update the last time update.
            _userSnapshot[user][campaignId].lastUpdateTime = uint40(block.timestamp);
        }
    }
}
