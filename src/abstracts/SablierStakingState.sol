// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";
import { ISablierStakingState } from "../interfaces/ISablierStakingState.sol";
import { Errors } from "../libraries/Errors.sol";
import { Amounts, GlobalSnapshot, StakedStream, StakingCampaign, UserSnapshot } from "../types/DataTypes.sol";

/// @title SablierStakingState
/// @notice Contract with state variables (storage and constants) for the {SablierStaking} contract, respective getters
/// and helpful modifiers.
abstract contract SablierStakingState is ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    bytes32 public constant override LOCKUP_WHITELIST_ROLE = keccak256("LOCKUP_WHITELIST_ROLE");

    /// @inheritdoc ISablierStakingState
    uint256 public override nextCampaignId;

    /// @notice Tracks the global rewards data and total staked amount for a given campaign.
    /// @dev See the documentation for GlobalSnapshot in {DataTypes}.
    mapping(uint256 campaignId => GlobalSnapshot snapshot) internal _globalSnapshot;

    /// @notice Indicates whether the Lockup contract is whitelisted to stake into this contract.
    mapping(ISablierLockupNFT lockup => bool isWhitelisted) internal _lockupWhitelist;

    /// @notice Reverse lookup to get the campaign ID and the original owner of the staked stream.
    /// @dev See the documentation for StakedStream in {DataTypes}.
    mapping(ISablierLockupNFT lockup => mapping(uint256 streamId => StakedStream details)) internal _stakedStream;

    /// @notice The campaign parameters mapped by the campaign ID.
    /// @dev See the documentation for StakingCampaign in {DataTypes}.
    mapping(uint256 campaignId => StakingCampaign campaign) internal _stakingCampaign;

    /// @notice Stores the user's staking details for each campaign.
    /// @dev See the documentation for UserSnapshot in {DataTypes}.
    mapping(address user => mapping(uint256 campaignId => UserSnapshot snapshot)) internal _userSnapshot;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks that the campaign is active by checking that it is not canceled and that the current time is
    /// between the campaign's start and end times.
    modifier isActive(uint256 campaignId) {
        _revertIfCanceled(campaignId);
        _revertIfCampaignNotOngoing(campaignId);
        _;
    }

    /// @notice Checks that the campaign is not canceled.
    modifier notCanceled(uint256 campaignId) {
        _revertIfCanceled(campaignId);
        _;
    }

    /// @notice Checks that `campaignId` does not reference a null campaign.
    modifier notNull(uint256 campaignId) {
        _revertIfNull(campaignId);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    function amountStakedByUser(
        uint256 campaignId,
        address user
    )
        external
        view
        notNull(campaignId)
        returns (Amounts memory)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserSnapshot memory snapshot = _userSnapshot[user][campaignId];

        return Amounts({
            streamsCount: snapshot.streamsCount,
            directAmountStaked: snapshot.directAmountStaked,
            streamAmountStaked: snapshot.totalAmountStaked - snapshot.directAmountStaked,
            totalAmountStaked: snapshot.totalAmountStaked
        });
    }

    /// @inheritdoc ISablierStakingState
    function getAdmin(uint256 campaignId) external view notNull(campaignId) returns (address) {
        return _stakingCampaign[campaignId].admin;
    }

    /// @inheritdoc ISablierStakingState
    function getEndTime(uint256 campaignId) external view notNull(campaignId) returns (uint40) {
        return _stakingCampaign[campaignId].endTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardToken(uint256 campaignId) external view notNull(campaignId) returns (IERC20) {
        return _stakingCampaign[campaignId].rewardToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStakingToken(uint256 campaignId) external view notNull(campaignId) returns (IERC20) {
        return _stakingCampaign[campaignId].stakingToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStartTime(uint256 campaignId) external view notNull(campaignId) returns (uint40) {
        return _stakingCampaign[campaignId].startTime;
    }

    /// @inheritdoc ISablierStakingState
    function getTotalRewards(uint256 campaignId) external view notNull(campaignId) returns (uint128) {
        return _stakingCampaign[campaignId].totalRewards;
    }

    /// @inheritdoc ISablierStakingState
    function globalSnapshot(uint256 campaignId)
        external
        view
        notNull(campaignId)
        returns (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled)
    {
        GlobalSnapshot memory snapshot = _globalSnapshot[campaignId];

        lastUpdateTime = snapshot.lastUpdateTime;
        rewardsDistributedPerTokenScaled = snapshot.rewardsDistributedPerTokenScaled;
    }

    /// @inheritdoc ISablierStakingState
    function isLockupWhitelisted(ISablierLockupNFT lockup) external view returns (bool) {
        // Check: the lockup is not the zero address.
        if (address(lockup) == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        return _lockupWhitelist[lockup];
    }

    /// @inheritdoc ISablierStakingState
    function stakedStream(
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        view
        returns (uint256 campaignId, address owner)
    {
        // Check: the lockup is not the zero address.
        if (address(lockup) == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        // Check: the stream ID is staked in a campaign.
        if (_stakedStream[lockup][streamId].campaignId == 0) {
            revert Errors.SablierStakingState_StreamNotStaked(lockup, streamId);
        }

        campaignId = _stakedStream[lockup][streamId].campaignId;
        owner = _stakedStream[lockup][streamId].owner;
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStaked(uint256 campaignId) external view notNull(campaignId) returns (uint128) {
        return _globalSnapshot[campaignId].totalAmountStaked;
    }

    /// @inheritdoc ISablierStakingState
    function userSnapshot(
        uint256 campaignId,
        address user
    )
        external
        view
        notNull(campaignId)
        returns (uint40 lastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserSnapshot memory snapshot = _userSnapshot[user][campaignId];

        lastUpdateTime = snapshot.lastUpdateTime;
        rewardsEarnedPerTokenScaled = snapshot.rewardsEarnedPerTokenScaled;
        rewards = snapshot.rewards;
    }

    /// @inheritdoc ISablierStakingState
    function wasCanceled(uint256 campaignId) external view notNull(campaignId) returns (bool) {
        return _stakingCampaign[campaignId].wasCanceled;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the campaign is not ongoing.
    function _revertIfCampaignNotOngoing(uint256 campaignId) private view {
        uint40 currentTimestamp = uint40(block.timestamp);
        StakingCampaign memory campaign = _stakingCampaign[campaignId];

        // Check: the campaign is ongoing by comparing the current timestamp with the campaign's start and end times.
        bool isCampaignOngoing = campaign.startTime <= currentTimestamp && currentTimestamp <= campaign.endTime;
        if (!isCampaignOngoing) {
            revert Errors.SablierStakingState_CampaignNotActive(campaignId, campaign.startTime, campaign.endTime);
        }
    }

    /// @dev Reverts if the campaign is canceled.
    function _revertIfCanceled(uint256 campaignId) private view {
        if (_stakingCampaign[campaignId].wasCanceled) {
            revert Errors.SablierStakingState_CampaignCanceled(campaignId);
        }
    }

    /// @dev Reverts if the campaign does not exist.
    function _revertIfNull(uint256 campaignId) private view {
        if (_stakingCampaign[campaignId].admin == address(0)) {
            revert Errors.SablierStakingState_CampaignDoesNotExist(campaignId);
        }
    }
}
