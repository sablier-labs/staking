// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NoDelegateCall } from "@sablier/evm-utils/src/NoDelegateCall.sol";
import { RoleAdminable } from "@sablier/evm-utils/src/RoleAdminable.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { SablierStakingState } from "./abstracts/SablierStakingState.sol";
import { ISablierLockupNFT } from "./interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "./interfaces/ISablierStaking.sol";
import { Errors } from "./libraries/Errors.sol";
import { GlobalSnapshot, StakedStream, StakingCampaign, UserSnapshot } from "./types/DataTypes.sol";

/// @title SablierStaking
/// @notice See the documentation in {ISablierStaking}.
contract SablierStaking is
    ERC721Holder, // 1 inherited component
    ISablierStaking, // 6 inherited components
    NoDelegateCall, // 0 inherited components
    RoleAdminable, // 3 inherited components
    SablierStakingState // 1 inherited component
{
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

    /// @inheritdoc ISablierLockupRecipient
    /// @notice Handles the hook call from the Lockup contract when withdraw is called on a staked stream.
    /// @dev This function reverts and does not permit withdrawing from a staked stream.
    ///
    /// @param streamId The ID of the stream on which withdraw is called.
    /// @return The required selector.
    function onSablierLockupWithdraw(
        uint256 streamId,
        address, /* caller */
        address, /* recipient */
        uint128 /* amount */
    )
        external
        view
        override
        returns (bytes4)
    {
        // Revert regardless of the parameters.
        revert Errors.SablierStaking_WithdrawNotAllowed(ISablierLockupNFT(msg.sender), streamId);
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
        // If the total staked tokens is zero, return 0.
        if (_globalSnapshot[campaignId].totalStakedTokens == 0) {
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
        // If the total staked tokens is zero, return 0.
        if (_globalSnapshot[campaignId].totalStakedTokens == 0) {
            return 0;
        }

        uint128 rewardPerSecond = _rewardRate(campaignId);

        // Calculate the reward distributed per second.
        return rewardPerSecond / _globalSnapshot[campaignId].totalStakedTokens;
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
        returns (uint128 amountRefunded)
    {
        // Load the campaign from storage into memory.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Check: the campaign is not canceled already.
        if (campaign.wasCanceled) {
            revert Errors.SablierStaking_CampaignAlreadyCanceled();
        }

        // Check: `msg.sender` is the campaign admin.
        if (msg.sender != campaign.admin) {
            revert Errors.SablierStaking_CallerNotCampaignAdmin(msg.sender, campaign.admin);
        }

        // Check: the campaign start time is in the future.
        if (campaign.startTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignAlreadyStarted(campaign.startTime, uint40(block.timestamp));
        }

        // Effect: set the campaign as canceled.
        _stakingCampaign[campaignId].wasCanceled = true;

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
        returns (uint128 rewards)
    {
        // Effect: snapshot rewards data to the latest values.
        _snapshotRewards(campaignId, msg.sender);

        // Load rewards from storage into memory.
        rewards = _userSnapshot[msg.sender][campaignId].rewards;

        // Check: `msg.sender` has rewards to claim.
        if (rewards == 0) {
            revert Errors.SablierStaking_NoRewardsToClaim(campaignId, msg.sender);
        }

        // Effect: set the rewards to 0.
        _userSnapshot[msg.sender][campaignId].rewards = 0;

        // Effect: update the last update time.
        _userSnapshot[msg.sender][campaignId].lastUpdateTime = uint40(block.timestamp);

        // Interaction: transfer the reward to `msg.sender`.
        IERC20 rewardToken = _stakingCampaign[campaignId].rewardToken;
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
        _stakingCampaign[campaignId] = StakingCampaign({
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

    /// @inheritdoc ISablierLockupRecipient
    /// @notice Handles the hook call from the Lockup contract when a staked stream is canceled.
    /// @dev This function permits cancelling a staked stream and adjusts the total staked tokens in the campaign
    /// accordingly.
    ///
    /// Notes:
    ///  - Updates global rewards and user rewards data.
    ///
    /// Requirements:
    ///  - Must not be delegate called.
    ///  - `msg.sender` must be a whitelisted Lockup contract.
    ///  - `streamId` must be staked in a campaign.
    ///
    /// @param streamId The ID of the stream on which cancel is called.
    /// @param senderAmount The amount of tokens refunded to the sender.
    /// @return The required selector.
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
        // Check: `msg.sender` is a whitelisted Lockup contract.
        if (!_lockupWhitelist[ISablierLockupNFT(msg.sender)]) {
            revert Errors.SablierStaking_UnauthorizedCaller();
        }

        StakedStream memory stakedStream = _stakedStream[ISablierLockupNFT(msg.sender)][streamId];

        // Check: the `streamId` is staked in a campaign.
        if (stakedStream.campaignId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(ISablierLockupNFT(msg.sender), streamId);
        }

        // Effect: snapshot rewards data to the latest values.
        _snapshotRewards(stakedStream.campaignId, stakedStream.owner);

        // Effect: decrease the total staked tokens in the campaign.
        _globalSnapshot[stakedStream.campaignId].totalStakedTokens -= senderAmount;

        // Effect: decrease the user's total staked tokens.
        _userSnapshot[stakedStream.owner][stakedStream.campaignId].totalStakedTokens -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    /// @inheritdoc ISablierStaking
    function snapshotRewards(uint256 campaignId, address user) external override noDelegateCall {
        // Effect: snapshot rewards data to the latest values for `user`.
        _snapshotRewards(campaignId, user);
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20Token(uint256 campaignId, uint128 amount) external override noDelegateCall notNull(campaignId) {
        // Check: the campaign is not canceled.
        _revertIfCanceled(campaignId);

        // Retrieve the campaign from storage into memory.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Check: the campaign end time is in the future.
        if (campaign.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignHasEnded(campaign.endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStaking_StakingZeroAmount();
        }

        // Effect: update rewards for `msg.sender`.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: update total staked tokens in the campaign.
        _globalSnapshot[campaignId].totalStakedTokens += amount;

        // Retrieve the user snapshot from storage into memory.
        UserSnapshot memory userSnapshot = _userSnapshot[msg.sender][campaignId];

        // Effect: update total staked tokens by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].totalStakedTokens = userSnapshot.totalStakedTokens + amount;

        // Effect: update direct tokens staked by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].directStakedTokens = userSnapshot.directStakedTokens + amount;

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
    {
        // Check: the campaign is not canceled.
        _revertIfCanceled(campaignId);

        // Check: the lockup is whitelisted.
        if (!_lockupWhitelist[lockup]) {
            revert Errors.SablierStaking_LockupNotWhitelisted(lockup);
        }

        // Retrieve the campaign from storage into memory.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Check: the campaign end time is in the future.
        if (campaign.endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStaking_CampaignHasEnded(campaign.endTime);
        }

        // Check: the stream's underlying token is the same as the campaign's staking token.
        IERC20 underlyingToken = lockup.getUnderlyingToken(streamId);
        if (underlyingToken != campaign.stakingToken) {
            revert Errors.SablierStaking_UnderlyingTokenDifferent(underlyingToken, campaign.stakingToken);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = _amountInStream(lockup, streamId);

        // Check: the amount in stream is not zero, i.e. the stream is not depleted.
        if (amountInStream == 0) {
            revert Errors.SablierStaking_DepletedStream(lockup, streamId);
        }

        // Effect: update rewards.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: update total staked tokens in the campaign.
        _globalSnapshot[campaignId].totalStakedTokens += amountInStream;

        // Retrieve the user snapshot from storage into memory.
        UserSnapshot memory userSnapshot = _userSnapshot[msg.sender][campaignId];

        // Effect: update total staked tokens by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].totalStakedTokens = userSnapshot.totalStakedTokens + amountInStream;

        // Effect: update the number of streams staked by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].streamsCount = userSnapshot.streamsCount + 1;

        // Effect: update the `StakedStream` mapping.
        _stakedStream[lockup][streamId] = StakedStream({ campaignId: campaignId, owner: msg.sender });

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
            revert Errors.SablierStaking_UnstakingZeroAmount();
        }

        // Retrieve the user snapshot from storage into memory.
        UserSnapshot memory userSnapshot = _userSnapshot[msg.sender][campaignId];

        // Check: `amount` is not greater than the direct staked tokens.
        if (amount > userSnapshot.directStakedTokens) {
            revert Errors.SablierStaking_AmountExceedsStakedAmount(campaignId, amount, userSnapshot.directStakedTokens);
        }

        // Effect: update rewards.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: reduce total staked tokens in the campaign.
        _globalSnapshot[campaignId].totalStakedTokens -= amount;

        // Effect: reduce total staked tokens by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].totalStakedTokens = userSnapshot.totalStakedTokens - amount;

        // Effect: reduce direct staked tokens by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].directStakedTokens = userSnapshot.directStakedTokens - amount;

        // Interaction: transfer the tokens to `msg.sender`.
        _stakingCampaign[campaignId].stakingToken.safeTransfer({ to: msg.sender, value: amount });

        // Log the event.
        emit UnstakeERC20Token(campaignId, msg.sender, amount);
    }

    /// @inheritdoc ISablierStaking
    function unstakeLockupNFT(ISablierLockupNFT lockup, uint256 streamId) external override noDelegateCall {
        StakedStream memory stakedStream = _stakedStream[lockup][streamId];
        uint256 campaignId = stakedStream.campaignId;

        // Check: stream ID associated with `lockup` is staked in a campaign.
        if (campaignId == 0) {
            revert Errors.SablierStaking_StreamNotStaked(lockup, streamId);
        }

        // Check: `msg.sender` is the original owner of the stream.
        if (msg.sender != stakedStream.owner) {
            revert Errors.SablierStaking_CallerNotStreamOwner(lockup, streamId, msg.sender, stakedStream.owner);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = _amountInStream(lockup, streamId);

        // Effect: update rewards.
        _snapshotRewards(campaignId, msg.sender);

        // Effect: reduce total staked tokens in the campaign.
        _globalSnapshot[campaignId].totalStakedTokens -= amountInStream;

        // Retrieve the user snapshot from storage into memory.
        UserSnapshot memory userSnapshot = _userSnapshot[msg.sender][campaignId];

        // Effect: reduce total staked tokens by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].totalStakedTokens = userSnapshot.totalStakedTokens - amountInStream;

        // Effect: reduce the number of streams staked by `msg.sender`.
        _userSnapshot[msg.sender][campaignId].streamsCount = userSnapshot.streamsCount - 1;

        // Effect: delete the `StakedStream` mapping.
        delete _stakedStream[lockup][streamId];

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

    /// @notice Returns the amount available in the stream.
    /// @dev The following function determines the amounts of tokens in a stream irrespective of its cancelable status
    /// using the following formula: stream amount = (amount deposited - amount withdrawn - amount refunded).
    function _amountInStream(ISablierLockupNFT lockup, uint256 streamId) private view returns (uint128 amount) {
        return lockup.getDepositedAmount(streamId) - lockup.getWithdrawnAmount(streamId)
            - lockup.getRefundedAmount(streamId);
    }

    /// @notice Calculates the reward distributed per second without checking if the campaign is active.
    function _rewardRate(uint256 campaignId) private view returns (uint128) {
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Calculate the reward duration.
        uint40 rewardDuration = campaign.endTime - campaign.startTime;

        // Calculate the reward rate.
        return campaign.totalRewards / rewardDuration;
    }

    /// @notice Calculates cumulative rewards distributed since the last snapshot.
    /// @dev It assumes that the campaign has started and the last time update is less than the campaign end time.
    function _rewardsDistributedSinceLastSnapshot(uint256 campaignId)
        private
        view
        returns (uint128 rewardsDistributed)
    {
        GlobalSnapshot memory globalSnapshot = _globalSnapshot[campaignId];

        // If the total staked tokens is 0, return 0.
        if (globalSnapshot.totalStakedTokens == 0) {
            return 0;
        }

        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        uint40 startingTimestamp;
        uint40 endingTimestamp;

        // If the last update time is less than the start time, the starting timestamp is the campaign start time.
        if (globalSnapshot.lastUpdateTime <= campaign.startTime) {
            startingTimestamp = campaign.startTime;
        } else {
            startingTimestamp = globalSnapshot.lastUpdateTime;
        }

        // If the end time has passed, the ending timestamp is the campaign end time.
        if (campaign.endTime <= uint40(block.timestamp)) {
            endingTimestamp = campaign.endTime;
        } else {
            endingTimestamp = uint40(block.timestamp);
        }

        uint40 elapsedTime;
        uint40 campaignDuration;

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the elapsed time and the total campaign duration.
            elapsedTime = endingTimestamp - startingTimestamp;
            campaignDuration = campaign.endTime - campaign.startTime;
        }

        // If elapsed time is equal to the campaign duration, return the total rewards.
        if (elapsedTime == campaignDuration) {
            return campaign.totalRewards;
        }

        // Safe to use `unchecked` because the calculations cannot overflow.
        unchecked {
            // Calculate the total rewards distributed since the last snapshot.
            rewardsDistributed = uint128((elapsedTime * campaign.totalRewards) / campaignDuration);
        }

        return rewardsDistributed;
    }

    /// @notice Calculates cumulative rewards distributed per ERC20 token since the last snapshot.
    function _rewardsDistributedPerTokenSinceLastSnapshot(uint256 campaignId) private view returns (uint128) {
        return _rewardsDistributedSinceLastSnapshot(campaignId) / _globalSnapshot[campaignId].totalStakedTokens;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Snapshots rewards data for the specified campaign and user.
    /// @dev It does nothing if the campaign has not started or if the last time update is not less than the campaign
    /// end time.
    function _snapshotRewards(uint256 campaignId, address user) private {
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Return if the campaign has not started.
        if (uint40(block.timestamp) < campaign.startTime) {
            return;
        }

        GlobalSnapshot memory globalSnapshot = _globalSnapshot[campaignId];

        // Retrieve the rewards distributed per ERC20 token since the last snapshot.
        uint128 rewardsDistributedPerTokenSinceLastSnapshot = _rewardsDistributedPerTokenSinceLastSnapshot(campaignId);

        uint128 totalRewardsDistributedPerToken = globalSnapshot.rewardsDistributedPerToken;

        // Update the global snapshot if:
        //  - The rewards distributed per ERC20 token since the last snapshot is greater than 0.
        //  - The last time update is less than the campaign end time.
        if (rewardsDistributedPerTokenSinceLastSnapshot > 0 && globalSnapshot.lastUpdateTime < campaign.endTime) {
            // Update the cumulative rewards distributed per ERC20 token since the beginning of the campaign.
            totalRewardsDistributedPerToken += rewardsDistributedPerTokenSinceLastSnapshot;

            // Effect: update the rewards distributed per ERC20 token.
            _globalSnapshot[campaignId].rewardsDistributedPerToken = totalRewardsDistributedPerToken;
        }

        // Effect: update the last time update.
        _globalSnapshot[campaignId].lastUpdateTime = uint40(block.timestamp);

        UserSnapshot memory userSnapshot = _userSnapshot[user][campaignId];

        uint128 updatedUserRewards;

        // Update the user snapshot if:
        //  - The user has tokens staked.
        //  - The last time update is less than the campaign end time.
        if (userSnapshot.totalStakedTokens > 0 && userSnapshot.lastUpdateTime < campaign.endTime) {
            // Compute the rewards earned per ERC20 token by the user since the previous snapshot.
            uint128 rewardsEarnedPerTokenSinceLastSnapshot =
                totalRewardsDistributedPerToken - userSnapshot.rewardsEarnedPerToken;

            // Compute the new rewards earned by the user since the last snapshot.
            uint128 rewardsEarnedSinceLastSnapshot =
                rewardsEarnedPerTokenSinceLastSnapshot * userSnapshot.totalStakedTokens;

            // Effect: update the rewards earned by the user.
            updatedUserRewards = userSnapshot.rewards + rewardsEarnedSinceLastSnapshot;
            _userSnapshot[user][campaignId].rewards = updatedUserRewards;

            // Effect: update the rewards earned per ERC20 token by the user.
            _userSnapshot[user][campaignId].rewardsEarnedPerToken = totalRewardsDistributedPerToken;

            // Effect: update the last time update.
            _userSnapshot[user][campaignId].lastUpdateTime = uint40(block.timestamp);
        }

        // Log the event.
        emit SnapshotRewards({
            campaignId: campaignId,
            lastUpdateTime: uint40(block.timestamp),
            rewardsDistributedPerToken: totalRewardsDistributedPerToken,
            user: user,
            userRewards: updatedUserRewards,
            userStakedTokens: userSnapshot.totalStakedTokens
        });
    }
}
