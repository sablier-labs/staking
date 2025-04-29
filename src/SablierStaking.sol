// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { UD60x18, ud, ZERO } from "@prb/math/src/UD60x18.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { ISablierLockupNFT } from "./interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "./interfaces/ISablierStaking.sol";
import { Errors } from "./libraries/Errors.sol";
import { GlobalRewards, SablierLockupNFT, StakedStream, StakingCampaign, UserRewards } from "./types/DataTypes.sol";

/// @title SablierStakingVaults
/// @notice See the documentation in {ISablierStakingVaults}.
contract SablierStaking is ISablierStaking, ERC721Holder {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    mapping(uint256 campaignId => GlobalRewards snapshot) private _globalSnapshot;

    mapping(ISablierLockupNFT lockupAddress => mapping(uint256 streamId => StakedStream details)) private _stakedStream;

    mapping(uint256 campaignId => StakingCampaign campaign) private _stakingCampaign;

    mapping(address user => mapping(uint256 campaignId => UserRewards)) private _userRewards;

    /// @inheritdoc ISablierStaking
    uint256 public override nextCampaignId;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier notNull(uint256 campaignId) {
        _notNull(campaignId);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        // Set the next campaign ID to 1.
        nextCampaignId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function claimableRewards(
        uint256 campaignId,
        address user
    )
        external
        view
        override
        notNull(campaignId)
        returns (uint256 amount)
    {
        // Retrieve the user snapshot.
        UserRewards memory userRewards = _userRewards[user][campaignId];

        return userRewards.rewards;
    }

    /// @inheritdoc ISablierStaking
    function getAdmin(uint256 campaignId) external view override notNull(campaignId) returns (address) {
        return _stakingCampaign[campaignId].admin;
    }

    /// @inheritdoc ISablierStaking
    function getEndTime(uint256 campaignId) external view override notNull(campaignId) returns (uint40) {
        return _stakingCampaign[campaignId].endTime;
    }

    /// @inheritdoc ISablierStaking
    function getStakingToken(uint256 campaignId) external view override notNull(campaignId) returns (IERC20) {
        return _stakingCampaign[campaignId].stakingToken;
    }

    /// @inheritdoc ISablierStaking
    function getStartTime(uint256 campaignId) external view override notNull(campaignId) returns (uint40) {
        return _stakingCampaign[campaignId].startTime;
    }

    /// @inheritdoc ISablierStaking
    function getRewardToken(uint256 campaignId) external view override notNull(campaignId) returns (IERC20) {
        return _stakingCampaign[campaignId].rewardToken;
    }

    /// @inheritdoc ISablierStaking
    function getTotalRewardsAmount(uint256 campaignId) external view override notNull(campaignId) returns (uint256) {
        return _stakingCampaign[campaignId].totalRewards;
    }

    /// @inheritdoc ISablierStaking
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(ISablierLockupRecipient).interfaceId;
    }

    /// @inheritdoc ISablierStaking
    function globalSnapshot(uint256 campaignId)
        external
        view
        override
        notNull(campaignId)
        returns (GlobalRewards memory)
    {
        return _globalSnapshot[campaignId];
    }

    /// @inheritdoc ISablierStaking
    function userSnapshot(
        uint256 campaignId,
        address user
    )
        external
        view
        override
        notNull(campaignId)
        returns (UserRewards memory)
    {
        if (user == address(0)) {
            revert Errors.SablierStakingCampaign_ZeroAddress();
        }

        return _userRewards[user][campaignId];
    }

    /// @inheritdoc ISablierStaking
    function totalStakedByUser(
        uint256 campaignId,
        address user
    )
        external
        view
        override
        notNull(campaignId)
        returns (uint256 totalLockupStreams, uint256 amountInLockupStream, uint256 amountInERC20)
    {
        if (user == address(0)) {
            revert Errors.SablierStakingCampaign_ZeroAddress();
        }

        UserRewards memory userStakingInfo = _userRewards[user][campaignId];

        // Get the amount in stream.
        uint128 amountInStream = userStakingInfo.totalStakedTokens - userStakingInfo.stakedERC20Amount;

        return (userStakingInfo.stakedStreamsCount, amountInStream, userStakingInfo.stakedERC20Amount);
    }

    /// @inheritdoc ISablierStaking
    function rewardPerSecond(uint256 campaignId) external view override notNull(campaignId) returns (uint256 amount) {
        // Retrieve the campaign data.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // If the total staked tokens is zero, return 0.
        if (_globalSnapshot[campaignId].totalStakedTokens == 0) {
            return 0;
        }

        // If the campaign has not started yet, return 0.
        if (campaign.startTime > uint40(block.timestamp)) {
            return 0;
        }

        // If the campaign has ended, return 0.
        if (campaign.endTime < uint40(block.timestamp)) {
            return 0;
        }

        // Calculate the reward distributed per second.
        amount = campaign.totalRewards / (campaign.endTime - campaign.startTime);
    }

    /// @inheritdoc ISablierStaking
    function rewardRatePerERC20(uint256 campaignId) external view override notNull(campaignId) returns (uint256) {
        // Retrieve the campaign data.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // If the total staked tokens is zero, return 0.
        if (_globalSnapshot[campaignId].totalStakedTokens == 0) {
            return 0;
        }

        // If the campaign has not started yet, return 0.
        if (campaign.startTime > uint40(block.timestamp)) {
            return 0;
        }

        // If the campaign has ended, return 0.
        if (campaign.endTime < uint40(block.timestamp)) {
            return 0;
        }

        // Calculate the reward distributed per second.
        return campaign.totalRewards / (campaign.endTime - campaign.startTime)
            / _globalSnapshot[campaignId].totalStakedTokens;
    }

    /// @inheritdoc ISablierStaking
    function stakingAPY(uint256 campaignId) external view override notNull(campaignId) returns (UD60x18 apy) {
        // Retrieve the campaign data.
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // If the total staked tokens is zero, return 0.
        if (_globalSnapshot[campaignId].totalStakedTokens == 0) {
            return ZERO;
        }

        // If the campaign has not started yet, return 0.
        if (campaign.startTime > uint40(block.timestamp)) {
            return ZERO;
        }

        // If the campaign has ended, return 0.
        if (campaign.endTime < uint40(block.timestamp)) {
            return ZERO;
        }

        // Calculate the approximate annualized rewards.
        uint256 annualizedRewards = (campaign.totalRewards * 365 days) / (campaign.endTime - campaign.startTime);

        // Calculate the staking APY.
        apy = ud(annualizedRewards).div(ud(_globalSnapshot[campaignId].totalStakedTokens));
    }

    /*//////////////////////////////////////////////////////////////////////////
                        USER-FACING STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStaking
    function cancelStakingCampaign(uint256 campaignId) external override notNull(campaignId) {
        // Check: only the admin can cancel the campaign.
        if (msg.sender != _stakingCampaign[campaignId].admin) {
            revert Errors.SablierStakingCampaign_UnauthorizedCaller(msg.sender, campaignId);
        }

        // Check: the campaign has not started yet.
        if (_stakingCampaign[campaignId].startTime <= uint40(block.timestamp)) {
            revert Errors.SablierStakingCampaign_CampaignHasStarted(campaignId, _stakingCampaign[campaignId].startTime);
        }

        // Effect: delete the campaign from storage.
        _stakingCampaign[campaignId].wasCanceled = true;

        // Interaction: transfer the reward tokens to the campaign admin.
        _stakingCampaign[campaignId].rewardToken.safeTransfer({
            to: msg.sender,
            value: _stakingCampaign[campaignId].totalRewards
        });
    }

    /// @inheritdoc ISablierStaking
    function claimRewards(uint256 campaignId) external notNull(campaignId) {
        // Effect: update rewards.
        _updateRewards(campaignId, msg.sender);

        // Retrieve the user snapshot.
        UserRewards memory userRewards = _userRewards[msg.sender][campaignId];

        // Check: `msg.sender` has rewards in the campaign.
        if (userRewards.rewards == 0) {
            revert Errors.SablierStakingCampaign_AmountZero();
        }

        // Effect: update the user value of rewards.
        _userRewards[msg.sender][campaignId].rewards = 0;

        // Interaction: transfer the reward tokens from this contract to `msg.sender`.
        IERC20 rewardToken = _stakingCampaign[campaignId].rewardToken;
        rewardToken.safeTransfer({ to: msg.sender, value: userRewards.rewards });
    }

    /// @inheritdoc ISablierStaking
    function createStakingCampaign(
        address initialAdmin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 rewardsAmount
    )
        external
        override
        returns (uint256 campaignId)
    {
        // Check: initial admin is not the zero address.
        if (initialAdmin == address(0)) {
            revert Errors.SablierStakingCampaign_ZeroAddress();
        }

        // Check: the campaign start time is not in the past.
        if (startTime < uint40(block.timestamp)) {
            revert Errors.SablierStakingCampaign_StartTimeInPast(startTime);
        }

        // Check: the end time is greater than the start time.
        if (endTime <= startTime) {
            revert Errors.SablierStakingCampaign_StartTimeExceedsEndTime(startTime, endTime);
        }

        // Check: the reward amount is not zero.
        if (rewardsAmount == 0) {
            revert Errors.SablierStakingCampaign_ZeroRewardAmount();
        }

        // Load the next campaign ID from storage.
        campaignId = nextCampaignId;

        // Effect: store the new campaign in the mapping.
        _stakingCampaign[campaignId] = StakingCampaign({
            admin: initialAdmin,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: rewardsAmount,
            wasCanceled: false
        });

        unchecked {
            // Effect: bump the next campaign ID.
            nextCampaignId = campaignId + 1;
        }

        // Interaction: transfer the reward tokens from the `msg.sender` to this contract.
        rewardToken.safeTransferFrom({ from: msg.sender, to: address(this), value: rewardsAmount });
    }

    function onSablierLockupCancel(
        uint256 streamId,
        address, /* sender */
        uint128 senderAmount,
        uint128 /* recipientAmount */
    )
        external
        override
        returns (bytes4 selector)
    {
        // Retrieve the staked stream data using `msg.sender` as the Lockup address.
        StakedStream memory stakedStream = _stakedStream[ISablierLockupNFT(msg.sender)][streamId];

        // Check: staked stream exists.
        if (stakedStream.owner == address(0)) {
            revert Errors.SablierStakingCampaign_UnauthorizedCaller(msg.sender, streamId);
        }

        // Effect: update rewards.
        _updateRewards(stakedStream.campaignId, stakedStream.owner);

        // Effect: update the global value of total staked tokens.
        _globalSnapshot[stakedStream.campaignId].totalStakedTokens -= senderAmount;

        // Effect: update the user value of total staked tokens.
        _userRewards[msg.sender][stakedStream.campaignId].totalStakedTokens -= senderAmount;

        return ISablierLockupRecipient.onSablierLockupCancel.selector;
    }

    function onSablierLockupWithdraw(
        uint256 streamId,
        address, /* caller */
        address, /* recipient */
        uint128 /* amount */
    )
        external
        pure
        override
        returns (bytes4)
    {
        // Revert on this hook call.
        revert Errors.SablierStakingCampaign_WithdrawDisabled(streamId);
    }

    function stakeLockupNFT(
        uint256 campaignId,
        SablierLockupNFT calldata lockupNFT
    )
        external
        override
        notNull(campaignId)
    {
        // Retrieve the staked stream data using `msg.sender` as the Lockup address.
        StakedStream memory stakedStream = _stakedStream[lockupNFT.lockupAddress][lockupNFT.streamId];

        // Check: the campaign is not canceled.
        if (_stakingCampaign[campaignId].wasCanceled) {
            revert Errors.SablierStakingCampaign_CampaignDoesNotExist(campaignId);
        }

        // Check: the streamId is not staked already.
        if (stakedStream.campaignId != 0) {
            revert Errors.SablierStakingCampaign_StreamAlreadyStaked(lockupNFT.streamId, stakedStream.campaignId);
        }

        // Check: the stream's underlying token is the same as the campaign's staking token.
        IERC20 underlyingToken = lockupNFT.lockupAddress.getUnderlyingToken(lockupNFT.streamId);
        if (underlyingToken != _stakingCampaign[campaignId].stakingToken) {
            revert Errors.SablierStakingCampaign_LockupTokenNotAllowed(
                underlyingToken, _stakingCampaign[campaignId].stakingToken
            );
        }

        // Check: the campaign end time is in the future.
        if (_stakingCampaign[campaignId].endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStakingCampaign_CampaignHasEnded(_stakingCampaign[campaignId].endTime);
        }

        // Retrieves the amount of token available in the stream.
        uint128 amountInStream = _amountInStream(lockupNFT.lockupAddress, lockupNFT.streamId);

        // Check: the amount in stream is not zero.
        if (amountInStream == 0) {
            revert Errors.SablierStakingCampaign_ZeroStakingAmount();
        }

        // Effect: update rewards.
        _updateRewards(campaignId, msg.sender);

        // Effect: update the global value of total staked tokens.
        _globalSnapshot[campaignId].totalStakedTokens += amountInStream;

        // Effect: update the user value of total staked tokens.
        _userRewards[msg.sender][campaignId].totalStakedTokens += amountInStream;

        // Effect: update the user value of staked streams count.
        _userRewards[msg.sender][campaignId].stakedStreamsCount++;

        // Effect: update the mapping of streamId to campaignId.
        _stakedStream[lockupNFT.lockupAddress][lockupNFT.streamId] =
            StakedStream({ campaignId: campaignId, owner: msg.sender });

        // Interaction: transfer the Lockup stream from the `msg.sender` to this contract.
        lockupNFT.lockupAddress.safeTransferFrom({ from: msg.sender, to: address(this), tokenId: lockupNFT.streamId });
    }

    /// @inheritdoc ISablierStaking
    function stakeERC20token(uint256 campaignId, uint128 amount) external override notNull(campaignId) {
        // Retrieve the staking tokens supported by the campaign.
        IERC20 stakingToken = _stakingCampaign[campaignId].stakingToken;

        // Check: the campaign is not canceled.
        if (_stakingCampaign[campaignId].wasCanceled) {
            revert Errors.SablierStakingCampaign_CampaignDoesNotExist(campaignId);
        }

        // Check: the campaign end time is in the future.
        if (_stakingCampaign[campaignId].endTime <= uint40(block.timestamp)) {
            revert Errors.SablierStakingCampaign_CampaignHasEnded(_stakingCampaign[campaignId].endTime);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStakingCampaign_ZeroStakingAmount();
        }

        // Effect: update rewards.
        _updateRewards(campaignId, msg.sender);

        // Effect: update the global value of total staked tokens.
        _globalSnapshot[campaignId].totalStakedTokens += amount;

        // Effect: update the user value of total staked tokens.
        _userRewards[msg.sender][campaignId].totalStakedTokens += amount;

        // Effect: update the user value of staked ERC20 amount.
        _userRewards[msg.sender][campaignId].stakedERC20Amount += amount;

        // Interaction: transfer the tokens from the `msg.sender` to this contract.
        stakingToken.safeTransferFrom({ from: msg.sender, to: address(this), value: amount });
    }

    /// @inheritdoc ISablierStaking
    function unstakeERC20token(uint256 campaignId, uint128 amount) external override notNull(campaignId) {
        UserRewards memory userStakingInfo = _userRewards[msg.sender][campaignId];

        // Check: `msg.sender` has tokens staked in the campaign.
        if (userStakingInfo.stakedERC20Amount == 0) {
            revert Errors.SablierStakingCampaign_ERC20StakingAmountZero(campaignId, msg.sender);
        }

        // Check: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierStakingCampaign_AmountZero();
        }

        // Check: amount to withdraw is not greater than the staked ERC20 amount.
        if (amount > userStakingInfo.stakedERC20Amount) {
            revert Errors.SablierStakingCampaign_ExceedStakedAmount({
                campaignId: campaignId,
                amountToUnstake: amount,
                totalStakedAmount: userStakingInfo.stakedERC20Amount
            });
        }

        // Effect: update rewards.
        _updateRewards(campaignId, msg.sender);

        // Effect: update the global value of total staked tokens.
        _globalSnapshot[campaignId].totalStakedTokens -= amount;

        // Effect: update the user value of total staked tokens.
        _userRewards[msg.sender][campaignId].totalStakedTokens -= amount;

        // Effect: update the user value of staked streams count.
        _userRewards[msg.sender][campaignId].stakedStreamsCount--;

        // Effect: update the user value of staked ERC20 amount.
        _userRewards[msg.sender][campaignId].stakedERC20Amount -= amount;

        // Interaction: transfer the tokens from this contract to `msg.sender`.
        IERC20 stakingToken = _stakingCampaign[campaignId].stakingToken;
        stakingToken.safeTransfer({ to: msg.sender, value: amount });
    }

    /// @inheritdoc ISablierStaking
    function unstakeLockupNFT(SablierLockupNFT calldata lockupNFT) external override {
        StakedStream memory stakedStream = _stakedStream[lockupNFT.lockupAddress][lockupNFT.streamId];

        // Check: the streamId is staked in a campaign.
        if (stakedStream.campaignId == 0) {
            revert Errors.SablierStakingCampaign_StreamNotStaked(
                address(lockupNFT.lockupAddress), lockupNFT.streamId, msg.sender
            );
        }

        // Check: `msg.sender` is the owner of the stream Id.
        if (stakedStream.owner != msg.sender) {
            revert Errors.SablierStakingCampaign_CallerNotStreamOwner({
                streamId: lockupNFT.streamId,
                caller: msg.sender,
                streamOwner: stakedStream.owner
            });
        }

        // Get the amount in stream.
        uint128 amountInStream = _amountInStream(lockupNFT.lockupAddress, lockupNFT.streamId);

        // Effect: update rewards.
        _updateRewards(stakedStream.campaignId, msg.sender);

        // Effect: update the global value of total staked tokens.
        _globalSnapshot[stakedStream.campaignId].totalStakedTokens -= amountInStream;

        // Effect: update the user value of total staked tokens.
        _userRewards[msg.sender][stakedStream.campaignId].totalStakedTokens -= amountInStream;

        // Effect: update the mapping of streamId to campaignId.
        delete _stakedStream[lockupNFT.lockupAddress][lockupNFT.streamId];

        // Interaction: transfer the Lockup stream from this contract to `msg.sender`.
        lockupNFT.lockupAddress.safeTransferFrom({ from: address(this), to: msg.sender, tokenId: lockupNFT.streamId });
    }

    /// @inheritdoc ISablierStaking
    function updateRewardsSnapshot(uint256 campaignId, address user) external override notNull(campaignId) {
        _updateRewards(campaignId, user);
    }

    /*//////////////////////////////////////////////////////////////////////////
                             PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Fetches the amount available in the stream.
    /// @dev The following function determines the amounts of tokens in a stream irrespective of its cancelable status
    /// using the following formula: stream amount = (amount deposited - amount withdrawn - amount refunded).
    function _amountInStream(ISablierLockupNFT lockupAddress, uint256 streamId) private view returns (uint128 amount) {
        return lockupAddress.getDepositedAmount(streamId) - lockupAddress.getWithdrawnAmount(streamId)
            - lockupAddress.getRefundedAmount(streamId);
    }

    /// @dev Returns the global rewards earned per ERC20 token since the last snapshot.
    function _globalSnapshotEarnedPerTokenSinceLastSnapshot(uint256 campaignId) private view returns (uint128) {
        StakingCampaign memory campaign = _stakingCampaign[campaignId];
        GlobalRewards memory globalRewards = _globalSnapshot[campaignId];

        // If the snapshot time is greater than or equal to the campaign end time, return 0.
        if (globalRewards.lastUpdateTIme >= campaign.endTime) {
            return 0;
        }

        // If the campaign start time is in the future, return 0.
        if (campaign.startTime >= uint40(block.timestamp)) {
            return 0;
        }

        // If the total staked tokens is 0, return 0.
        if (globalRewards.totalStakedTokens == 0) {
            return 0;
        }

        uint256 durationForRewardsCalculation;

        // If the end time has passed, calculate the duration from the snapshot time to the end time.
        if (campaign.endTime < uint40(block.timestamp)) {
            durationForRewardsCalculation = campaign.endTime - globalRewards.lastUpdateTIme;
        }
        // Else if the snapshot time is less than the campaign start time, calculate the duration from the start time to
        // the current block timestamp.
        else if (globalRewards.lastUpdateTIme < campaign.startTime) {
            durationForRewardsCalculation = uint40(block.timestamp) - campaign.startTime;
        }
        // Otherwise, calculate the duration from the snapshot time to the current block timestamp.
        else {
            durationForRewardsCalculation = uint40(block.timestamp) - globalRewards.lastUpdateTIme;
        }

        // Calculate the total campaign duration.
        uint256 campaignDuration = campaign.endTime - campaign.startTime;

        // Calculate the total rewards earned since the last snapshot.
        uint128 newTotalRewards = uint128((durationForRewardsCalculation * campaign.totalRewards) / campaignDuration);

        // Return the total rewards earned since last snapshot per ERC20.
        return newTotalRewards / campaign.totalRewards;
    }

    /// @dev Checks if the campaign exists by verifying if the admin address is not zero.
    function _notNull(uint256 campaignId) private view {
        if (_stakingCampaign[campaignId].admin == address(0)) {
            revert Errors.SablierStakingCampaign_CampaignDoesNotExist(campaignId);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Update rewards data globally as well as for the specified user.
    function _updateRewards(uint256 campaignId, address user) private {
        // Compute the global rewards earned per ERC20 token since the last snapshot.
        uint128 globalRewardsEarnedPerTokenSinceLastSnapshot =
            _globalSnapshotEarnedPerTokenSinceLastSnapshot(campaignId);

        // Compute the total rewards distributed per ERC20 token.
        uint128 totalRewardsDistributedPerToken =
            _globalSnapshot[campaignId].rewardsDistributedPerToken + globalRewardsEarnedPerTokenSinceLastSnapshot;

        // Effect: update the global rewards snapshot.
        _globalSnapshot[campaignId].lastUpdateTIme = uint40(block.timestamp);

        // Effect: update the global rewards distributed per ERC20 token if the value greater than 0.
        if (globalRewardsEarnedPerTokenSinceLastSnapshot > 0) {
            // Effect: update the global rewards distributed per ERC20 token.
            _globalSnapshot[campaignId].rewardsDistributedPerToken = totalRewardsDistributedPerToken;
        }

        // Load the user rewards data from storage.
        UserRewards memory userRewards = _userRewards[user][campaignId];

        // If the user has staked token, update the rewards per ERC20 token earned by the user.
        if (userRewards.totalStakedTokens > 0) {
            // Compute the rewards earned per ERC20 token by the user since the previous snapshot.
            uint128 earnedRewardsPerTokenSinceLastSnapshot =
                totalRewardsDistributedPerToken - userRewards.rewardsDistributedPerToken;

            // Compute the new rewards earned by the user since the last snapshot.
            uint128 newRewardsEarnedByUser = earnedRewardsPerTokenSinceLastSnapshot * userRewards.totalStakedTokens;

            // Effect: update the rewards per ERC20 token earned by the user.
            _userRewards[user][campaignId].rewardsDistributedPerToken = totalRewardsDistributedPerToken;

            // Effect: update the rewards earned by the user.
            _userRewards[user][campaignId].rewards += newRewardsEarnedByUser;
        }
    }
}
