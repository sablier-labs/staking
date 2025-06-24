// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";
import { ISablierStakingState } from "../interfaces/ISablierStakingState.sol";
import { Errors } from "../libraries/Errors.sol";
import { Campaign, GlobalSnapshot, StreamLookup, UserShares, UserSnapshot } from "../types/DataTypes.sol";

/// @title SablierStakingState
/// @notice See the documentation in {ISablierStakingState}.
abstract contract SablierStakingState is ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    bytes32 public constant override LOCKUP_WHITELIST_ROLE = keccak256("LOCKUP_WHITELIST_ROLE");

    /// @inheritdoc ISablierStakingState
    uint256 public override nextCampaignId;

    /// @notice The campaign parameters mapped by the campaign ID.
    /// @dev See the documentation for Campaign in {DataTypes}.
    mapping(uint256 campaignId => Campaign campaign) internal _campaign;

    /// @notice Tracks the global rewards data and total staked amount for a given campaign.
    /// @dev See the documentation for GlobalSnapshot in {DataTypes}.
    mapping(uint256 campaignId => GlobalSnapshot snapshot) internal _globalSnapshot;

    /// @notice Indicates whether the Lockup contract is whitelisted to stake into this contract.
    mapping(ISablierLockupNFT lockup => bool isWhitelisted) internal _lockupWhitelist;

    /// @notice Get the campaign ID and the original owner of the staked stream.
    /// @dev See the documentation for StreamLookup in {DataTypes}.
    mapping(ISablierLockupNFT lockup => mapping(uint256 streamId => StreamLookup lookup)) internal _streamLookup;

    /// @notice The total amount of tokens staked in a campaign (both direct staking and through Sablier streams).
    mapping(uint256 campaignId => uint128 amount) internal _totalAmountStaked;

    /// @notice The user's shares of tokens staked in a campaign.
    /// @dev See the documentation for UserShares in {DataTypes}.
    mapping(address user => mapping(uint256 campaignId => UserShares shares)) internal _userShares;

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
    function getAdmin(uint256 campaignId) external view notNull(campaignId) returns (address) {
        return _campaign[campaignId].admin;
    }

    /// @inheritdoc ISablierStakingState
    function getEndTime(uint256 campaignId) external view notNull(campaignId) returns (uint40) {
        return _campaign[campaignId].endTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardToken(uint256 campaignId) external view notNull(campaignId) returns (IERC20) {
        return _campaign[campaignId].rewardToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStakingToken(uint256 campaignId) external view notNull(campaignId) returns (IERC20) {
        return _campaign[campaignId].stakingToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStartTime(uint256 campaignId) external view notNull(campaignId) returns (uint40) {
        return _campaign[campaignId].startTime;
    }

    /// @inheritdoc ISablierStakingState
    function getTotalRewards(uint256 campaignId) external view notNull(campaignId) returns (uint128) {
        return _campaign[campaignId].totalRewards;
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
    function streamLookup(
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
        if (_streamLookup[lockup][streamId].campaignId == 0) {
            revert Errors.SablierStakingState_StreamNotStaked(lockup, streamId);
        }

        campaignId = _streamLookup[lockup][streamId].campaignId;
        owner = _streamLookup[lockup][streamId].owner;
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStaked(uint256 campaignId) external view notNull(campaignId) returns (uint128) {
        return _totalAmountStaked[campaignId];
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStakedByUser(
        uint256 campaignId,
        address user
    )
        external
        view
        notNull(campaignId)
        returns (uint128)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserShares memory shares = _userShares[user][campaignId];

        return shares.directAmountStaked + shares.streamAmountStaked;
    }

    /// @inheritdoc ISablierStakingState
    function userShares(
        uint256 campaignId,
        address user
    )
        external
        view
        notNull(campaignId)
        returns (uint128 streamsCount, uint128 streamAmountStaked, uint128 directAmountStaked)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserShares memory shares = _userShares[user][campaignId];

        return (shares.streamsCount, shares.streamAmountStaked, shares.directAmountStaked);
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
        return _campaign[campaignId].wasCanceled;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the campaign is not ongoing.
    function _revertIfCampaignNotOngoing(uint256 campaignId) private view {
        uint40 currentTimestamp = uint40(block.timestamp);
        Campaign memory campaign = _campaign[campaignId];

        // Check: the campaign is ongoing by comparing the current timestamp with the campaign's start and end times.
        bool isCampaignOngoing = campaign.startTime <= currentTimestamp && currentTimestamp <= campaign.endTime;
        if (!isCampaignOngoing) {
            revert Errors.SablierStakingState_CampaignNotActive(campaignId, campaign.startTime, campaign.endTime);
        }
    }

    /// @dev Reverts if the campaign is canceled.
    function _revertIfCanceled(uint256 campaignId) private view {
        if (_campaign[campaignId].wasCanceled) {
            revert Errors.SablierStakingState_CampaignCanceled(campaignId);
        }
    }

    /// @dev Reverts if the campaign does not exist.
    function _revertIfNull(uint256 campaignId) private view {
        if (_campaign[campaignId].admin == address(0)) {
            revert Errors.SablierStakingState_CampaignDoesNotExist(campaignId);
        }
    }
}
