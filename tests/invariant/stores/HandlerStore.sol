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

    /// @dev Tracks rewards claimed by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 rewards)) public rewardsClaimed;

    /// @dev Tracks rewards distribution period for each pool.
    mapping(uint256 poolId => uint40 rewards) public rewardDistributionPeriod;

    /// @dev Tracks the last time rewards were updated for each staker in each pool.
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

    function addUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] += amount;
    }

    function subtractUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] -= amount;
    }

    function updateRewardsPeriodUpdatedAt(uint40 time) external {
        rewardsPeriodUpdatedAt = time;
    }

    function updateUserSnapshotTime(uint256 poolId, address staker, uint40 time) external {
        userSnapshotTime[poolId][staker] = time;
    }
}
