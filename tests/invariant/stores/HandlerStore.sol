// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

/// @dev Storage variables needed for handlers.
contract HandlerStore {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Tracks all pools created by the invariant handler.
    uint256[] public poolIds;

    /// @dev Tracks the time when rewards period was last updated for all pools.
    uint40 public rewardsPeriodUpdatedAt;

    /// @dev Tracks the amount of tokens staked by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 amount)) public amountStaked;

    /// @dev Maps stakers with the pool ID they have staked in.
    mapping(uint256 poolId => address[] stakers) public poolStakers;

    /// @dev Stores previous values for global rewards per token for each pool.
    mapping(uint256 poolId => uint256 rewardsPerTokenScaled) public globalRewardsPerTokenScaled;

    /// @dev Tracks the previous time global snapshot was taken for each pool.
    mapping(uint256 poolId => uint40 time) public globalSnapshotTime;

    /// @dev Tracks rewards claimed by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 rewards)) public rewardsClaimed;

    /// @dev Tracks rewards distribution period for each pool.
    mapping(uint256 poolId => uint40 rewards) public rewardDistributionPeriod;

    /// @dev Tracks the total rewards deposited across all rounds for each pool.
    mapping(uint256 poolId => uint128 totalRewardsDeposited) public totalRewardsDeposited;

    /// @dev Stores previous values for user rewards per token for each pool.
    mapping(uint256 poolId => mapping(address staker => uint256 rewardsPerTokenScaled)) public userRewardsPerTokenScaled;

    /// @dev Tracks the last time user snapshot was taken for each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint40 time)) public userSnapshotTime;

    /*//////////////////////////////////////////////////////////////////////////
                                      GETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function addPoolId(uint256 poolId) external {
        poolIds.push(poolId);
    }

    function addStaker(uint256 poolId, address staker) external {
        poolStakers[poolId].push(staker);
    }

    function lastPoolId() external view returns (uint256) {
        return poolIds[poolIds.length - 1];
    }

    function totalPools() external view returns (uint256) {
        return poolIds.length;
    }

    function totalStakers(uint256 poolId) external view returns (uint256) {
        return poolStakers[poolId].length;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      SETTERS
    //////////////////////////////////////////////////////////////////////////*/

    function addRewardsClaimed(uint256 poolId, address staker, uint128 rewards) external {
        rewardsClaimed[poolId][staker] += rewards;
    }

    function addRewardDistributionPeriod(uint256 poolId, uint40 period) external {
        rewardDistributionPeriod[poolId] += period;
    }

    function addTotalRewardsDeposited(uint256 poolId, uint128 amount) external {
        totalRewardsDeposited[poolId] += amount;
    }

    function addUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] += amount;
    }

    function subtractUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] -= amount;
    }

    function updateGlobalSnapshot(uint256 poolId, uint40 time, uint256 rewardsPerTokenScaled) external {
        globalRewardsPerTokenScaled[poolId] = rewardsPerTokenScaled;
        globalSnapshotTime[poolId] = time;
    }

    function updateRewardsPeriodUpdatedAt(uint40 time) external {
        rewardsPeriodUpdatedAt = time;
    }

    function updateUserSnapshot(uint256 poolId, address staker, uint40 time, uint256 rewardsPerTokenScaled) external {
        userRewardsPerTokenScaled[poolId][staker] = rewardsPerTokenScaled;
        userSnapshotTime[poolId][staker] = time;
    }
}
