// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";
import { ISablierStakingState } from "../interfaces/ISablierStakingState.sol";
import { Errors } from "../libraries/Errors.sol";
import { Pool, Status, StreamLookup, UserShares, UserSnapshot } from "../types/DataTypes.sol";

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

    /// @notice Indicates whether the Lockup contract is whitelisted to stake into this contract.
    mapping(ISablierLockupNFT lockup => bool isWhitelisted) internal _lockupWhitelist;

    /// @notice The Pool parameters mapped by the Pool ID.
    /// @dev See the documentation for Pool in {DataTypes}.
    mapping(uint256 poolId => Pool pool) internal _pool;

    /// @notice Get the Pool ID and the original owner of the staked stream.
    /// @dev See the documentation for StreamLookup in {DataTypes}.
    mapping(ISablierLockupNFT lockup => mapping(uint256 streamId => StreamLookup lookup)) internal _streamLookup;

    /// @notice The user's shares of tokens staked in a pool.
    /// @dev See the documentation for UserShares in {DataTypes}.
    mapping(address user => mapping(uint256 poolId => UserShares shares)) internal _userShares;

    /// @notice Stores the user's staking details for each pool.
    /// @dev See the documentation for UserSnapshot in {DataTypes}.
    mapping(address user => mapping(uint256 poolId => UserSnapshot snapshot)) internal _userSnapshot;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Modifier that checks that the pool is active.
    modifier isActive(uint256 poolId) {
        _revertIfNotActive(poolId);
        _;
    }

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
        return _pool[poolId].admin;
    }

    /// @inheritdoc ISablierStakingState
    function getEndTime(uint256 poolId) external view notNull(poolId) returns (uint40) {
        return _pool[poolId].endTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardToken(uint256 poolId) external view notNull(poolId) returns (IERC20) {
        return _pool[poolId].rewardToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStakingToken(uint256 poolId) external view notNull(poolId) returns (IERC20) {
        return _pool[poolId].stakingToken;
    }

    /// @inheritdoc ISablierStakingState
    function getStartTime(uint256 poolId) external view notNull(poolId) returns (uint40) {
        return _pool[poolId].startTime;
    }

    /// @inheritdoc ISablierStakingState
    function getRewardAmount(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _pool[poolId].rewardAmount;
    }

    /// @inheritdoc ISablierStakingState
    function getTotalStakedAmount(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _pool[poolId].totalStakedAmount;
    }

    /// @inheritdoc ISablierStakingState
    function globalSnapshot(uint256 poolId)
        external
        view
        notNull(poolId)
        returns (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled)
    {
        lastUpdateTime = _pool[poolId].lastUpdateTime;
        rewardsDistributedPerTokenScaled = _pool[poolId].rewardsDistributedPerTokenScaled;
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
    function status(uint256 poolId) external view override notNull(poolId) returns (Status) {
        // Return SCHEDULED if the start time is in the future.
        if (block.timestamp < _pool[poolId].startTime) {
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
        if (_streamLookup[lockup][streamId].poolId == 0) {
            revert Errors.SablierStakingState_StreamNotStaked(lockup, streamId);
        }

        poolId = _streamLookup[lockup][streamId].poolId;
        owner = _streamLookup[lockup][streamId].owner;
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStakedByUser(uint256 poolId, address user) external view notNull(poolId) returns (uint128) {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        return _userShares[user][poolId].directAmountStaked + _userShares[user][poolId].streamAmountStaked;
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

        return (_userShares[user][poolId].streamAmountStaked, _userShares[user][poolId].directAmountStaked);
    }

    /// @inheritdoc ISablierStakingState
    function userSnapshot(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        returns (uint256 rewardsEarnedPerTokenScaled, uint128 rewards)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        rewardsEarnedPerTokenScaled = _userSnapshot[user][poolId].rewardsEarnedPerTokenScaled;
        rewards = _userSnapshot[user][poolId].rewards;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Returns true if the pool is active.
    function _isActive(uint256 poolId) private view returns (bool) {
        Pool memory pool = _pool[poolId];
        uint40 currentTimestamp = uint40(block.timestamp);
        return pool.startTime <= currentTimestamp && currentTimestamp <= pool.endTime;
    }

    /// @dev Reverts if the pool is not active.
    function _revertIfNotActive(uint256 poolId) private view {
        if (!_isActive(poolId)) {
            revert Errors.SablierStakingState_NotActive(poolId);
        }
    }

    /// @dev Reverts if the pool ID does not exist.
    function _revertIfNull(uint256 poolId) private view {
        if (_pool[poolId].admin == address(0)) {
            revert Errors.SablierStakingState_PoolDoesNotExist(poolId);
        }
    }
}
