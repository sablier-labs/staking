// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";
import { ISablierStakingState } from "../interfaces/ISablierStakingState.sol";
import { Errors } from "../libraries/Errors.sol";
import { GlobalSnapshot, Pool, StreamLookup, UserShares, UserSnapshot } from "../types/DataTypes.sol";

/// @title SablierStakingState
/// @notice See the documentation in {ISablierStakingState}.
abstract contract SablierStakingState is ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierStakingState
    bytes32 public constant override LOCKUP_WHITELIST_ROLE = keccak256("LOCKUP_WHITELIST_ROLE");

    /// @inheritdoc ISablierStakingState
    uint256 public override nextPoolId;

    /// @notice The Pool parameters mapped by the Pool ID.
    /// @dev See the documentation for Pool in {DataTypes}.
    mapping(uint256 poolId => Pool pool) internal _pool;

    /// @notice Tracks the global rewards data and total staked amount for a given pool.
    /// @dev See the documentation for GlobalSnapshot in {DataTypes}.
    mapping(uint256 poolId => GlobalSnapshot snapshot) internal _globalSnapshot;

    /// @notice Indicates whether the Lockup contract is whitelisted to stake into this contract.
    mapping(ISablierLockupNFT lockup => bool isWhitelisted) internal _lockupWhitelist;

    /// @notice Get the Pool ID and the original owner of the staked stream.
    /// @dev See the documentation for StreamLookup in {DataTypes}.
    mapping(ISablierLockupNFT lockup => mapping(uint256 streamId => StreamLookup lookup)) internal _streamLookup;

    /// @notice The total amount of tokens staked in a pool (both direct staking and through Sablier streams).
    mapping(uint256 poolId => uint128 amount) internal _totalAmountStaked;

    /// @notice The user's shares of tokens staked in a pool.
    /// @dev See the documentation for UserShares in {DataTypes}.
    mapping(address user => mapping(uint256 poolId => UserShares shares)) internal _userShares;

    /// @notice Stores the user's staking details for each pool.
    /// @dev See the documentation for UserSnapshot in {DataTypes}.
    mapping(address user => mapping(uint256 poolId => UserSnapshot snapshot)) internal _userSnapshot;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks that the pool is active by checking that it was not closed and that the current time is between
    /// the pool's start and end times.
    modifier isActive(uint256 poolId) {
        _revertIfClosed(poolId);
        _revertIfOutsideRewardsPeriod(poolId);
        _;
    }

    /// @notice Checks that the pool was not closed by the admin.
    modifier notClosed(uint256 poolId) {
        _revertIfClosed(poolId);
        _;
    }

    /// @notice Checks that `poolId` does not reference to a non-existent pool.
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
    function getTotalRewards(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _pool[poolId].totalRewards;
    }

    /// @inheritdoc ISablierStakingState
    function globalSnapshot(uint256 poolId)
        external
        view
        notNull(poolId)
        returns (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled)
    {
        GlobalSnapshot memory snapshot = _globalSnapshot[poolId];

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
    function totalAmountStaked(uint256 poolId) external view notNull(poolId) returns (uint128) {
        return _totalAmountStaked[poolId];
    }

    /// @inheritdoc ISablierStakingState
    function totalAmountStakedByUser(uint256 poolId, address user) external view notNull(poolId) returns (uint128) {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserShares memory shares = _userShares[user][poolId];

        return shares.directAmountStaked + shares.streamAmountStaked;
    }

    /// @inheritdoc ISablierStakingState
    function userShares(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        returns (uint128 streamsCount, uint128 streamAmountStaked, uint128 directAmountStaked)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserShares memory shares = _userShares[user][poolId];

        return (shares.streamsCount, shares.streamAmountStaked, shares.directAmountStaked);
    }

    /// @inheritdoc ISablierStakingState
    function userSnapshot(
        uint256 poolId,
        address user
    )
        external
        view
        notNull(poolId)
        returns (uint40 lastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards)
    {
        // Check: the user is not the zero address.
        if (user == address(0)) {
            revert Errors.SablierStakingState_ZeroAddress();
        }

        UserSnapshot memory snapshot = _userSnapshot[user][poolId];

        lastUpdateTime = snapshot.lastUpdateTime;
        rewardsEarnedPerTokenScaled = snapshot.rewardsEarnedPerTokenScaled;
        rewards = snapshot.rewards;
    }

    /// @inheritdoc ISablierStakingState
    function wasClosed(uint256 poolId) external view notNull(poolId) returns (bool) {
        return _pool[poolId].wasClosed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Reverts if the pool was closed by the admin.
    function _revertIfClosed(uint256 poolId) private view {
        if (_pool[poolId].wasClosed) {
            revert Errors.SablierStakingState_PoolClosed(poolId);
        }
    }

    /// @dev Reverts if the pool ID does not exist.
    function _revertIfNull(uint256 poolId) private view {
        if (_pool[poolId].admin == address(0)) {
            revert Errors.SablierStakingState_PoolDoesNotExist(poolId);
        }
    }

    /// @dev Reverts if the current timestamp is not between the start and end times.
    function _revertIfOutsideRewardsPeriod(uint256 poolId) private view {
        uint40 currentTimestamp = uint40(block.timestamp);
        Pool memory pool = _pool[poolId];

        // Check: the timestamp is between the start and end times.
        bool isRewardsPeriodActive = pool.startTime <= currentTimestamp && currentTimestamp <= pool.endTime;
        if (!isRewardsPeriodActive) {
            revert Errors.SablierStakingState_OutsideRewardsPeriod(poolId, pool.startTime, pool.endTime);
        }
    }
}
