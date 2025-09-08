// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";
import { ISablierStakingState } from "../interfaces/ISablierStakingState.sol";
import { Errors } from "../libraries/Errors.sol";
import { Pool, Status, StreamLookup, UserAccount } from "../types/DataTypes.sol";

/// @title SablierStakingState
/// @notice See the documentation in {ISablierStakingState}.
abstract contract SablierStakingState is ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    /// @dev 0.1e18 represents 10%.
    UD60x18 public constant override MAX_FEE_ON_REWARDS = UD60x18.wrap(0.1e18);

    /// @inheritdoc ISablierStakingState
    uint256 public override nextPoolId;

    /// @notice The Pool parameters mapped by the Pool ID.
    /// @dev See the documentation for Pool in {DataTypes}.
    mapping(uint256 poolId => Pool pool) internal _pools;

    /// @notice Get the Pool ID and the original owner of the staked stream.
    /// @dev See the documentation for StreamLookup in {DataTypes}.
    mapping(ISablierLockupNFT lockup => mapping(uint256 streamId => StreamLookup lookup)) internal _streamsLookup;

    /// @notice Stores the user's staking details for each pool.
    /// @dev See the documentation for UserAccount in {DataTypes}.
    mapping(address user => mapping(uint256 poolId => UserAccount userAccount)) internal _userAccounts;

    /// @notice Indicates whether the Lockup contract is whitelisted to stake into this contract.
    mapping(ISablierLockupNFT lockup => bool isWhitelisted) internal _whitelistedLockups;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Modifier that checks that `poolId` does not reference to a non-existent pool.
    modifier notNull(uint256 poolId) {
        _revertIfNull(poolId);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          USER-FACING READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    function getAdmin(uint256 poolId) external view notNull(poolId) returns (address) {
        return _pools[poolId].admin;
    }

    /// @inheritdoc ISablierStakingState
    function getEndTime(uint256 poolId) external view notNull(poolId) returns (uint40) {
        return _pools[poolId].endTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardToken(uint256 poolId) external view notNull(poolId) returns (IERC20) {
        return _pools[poolId].rewardToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStakingToken(uint256 poolId) external view notNull(poolId) returns (IERC20) {
        return _pools[poolId].stakingToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStartTime(uint256 poolId) external view notNull(poolId) returns (uint40) {
        return _pools[poolId].startTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardAmount(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _pools[poolId].rewardAmount;
    }

    /// @inheritdoc ISablierStakingState
    function getTotalStakedAmount(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _pools[poolId].totalStakedAmount;
    }

    /// @inheritdoc ISablierStakingState
    function globalRptAtSnapshot(uint256 poolId)
        external
        view
        notNull(poolId)
        returns (uint40 snapshotTime, uint256 snapshotRptDistributedScaled)
    {
        snapshotTime = _pools[poolId].snapshotTime;
        snapshotRptDistributedScaled = _pools[poolId].snapshotRptDistributedScaled;
    }

    /// @inheritdoc ISablierStakingState
    function isLockupWhitelisted(ISablierLockupNFT lockup) external view returns (bool) {
        // Check: the lockup is not the zero address.
        if (address(lockup) == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        return _whitelistedLockups[lockup];
    }

    /// @inheritdoc ISablierStakingState
    function status(uint256 poolId) external view override notNull(poolId) returns (Status) {
        // Return SCHEDULED if the start time is in the future.
        if (block.timestamp < _pools[poolId].startTime) {
            return Status.SCHEDULED;
        }

        // Return ACTIVE if the staking period is active.
        if (_isActive(poolId)) {
            return Status.ACTIVE;
        }

        // Otherwise, return ENDED.
        return Status.ENDED;
    }

    /// @inheritdoc ISablierStakingState
    function streamLookup(
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        view
        returns (uint256 poolId, address owner)
    {
        // Check: the lockup is not the zero address.
        if (address(lockup) == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        // Check: the stream ID is staked in a pool.
        if (_streamsLookup[lockup][streamId].poolId == 0) {
            revert Errors.SablierStakingState_StreamNotStaked(lockup, streamId);
        }

        poolId = _streamsLookup[lockup][streamId].poolId;
        owner = _streamsLookup[lockup][streamId].owner;
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStakedByUser(uint256 poolId, address user) external view notNull(poolId) returns (uint128) {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        return _userAccounts[user][poolId].directAmountStaked + _userAccounts[user][poolId].streamAmountStaked;
    }

    /// @inheritdoc ISablierStakingState
    function userShares(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        returns (uint128 streamAmountStaked, uint128 directAmountStaked)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        streamAmountStaked = _userAccounts[user][poolId].streamAmountStaked;
        directAmountStaked = _userAccounts[user][poolId].directAmountStaked;
    }

    /// @inheritdoc ISablierStakingState
    function userRewards(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        returns (uint256 snapshotRptEarnedScaled, uint128 snapshotRewards)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        snapshotRptEarnedScaled = _userAccounts[user][poolId].snapshotRptEarnedScaled;
        snapshotRewards = _userAccounts[user][poolId].snapshotRewards;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Returns true if the pool is active.
    function _isActive(uint256 poolId) internal view returns (bool) {
        uint40 currentTimestamp = uint40(block.timestamp);
        return _pools[poolId].startTime <= currentTimestamp && currentTimestamp <= _pools[poolId].endTime;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the pool ID does not exist.
    function _revertIfNull(uint256 poolId) private view {
        if (_pools[poolId].admin == address(0)) {
            revert Errors.SablierStakingState_PoolDoesNotExist(poolId);
        }
    }
}
