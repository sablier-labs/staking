// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

/// @dev Storage variables needed for handlers.
contract HandlerStore {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Tracks all pools created by the invariant handler.
    uint256[] public poolIds;

    uint40 public rewardsDistributedAt;

    /// @dev Tracks the amount of tokens staked by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 amount)) public amountStaked;

    /// @dev Tracks the last time rewards were updated for each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint40 time)) public userSnapshotTime;

    /// @dev Maps stakers with the pool ID they have staked in.
    mapping(uint256 poolId => address[] stakers) public poolStakers;

    /// @dev Tracks rewards claimed by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 rewards)) public rewardsClaimed;

    /// @dev Tracks rewards distributed by each pool.
    mapping(uint256 poolId => uint128 rewards) public rewardsDistributed;

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

    function decreaseUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] -= amount;
    }

    function increaseUserStake(uint256 poolId, address staker, uint128 amount) external {
        amountStaked[poolId][staker] += amount;
    }

    function updateUserSnapshotTime(uint256 poolId, address staker, uint40 time) external {
        userSnapshotTime[poolId][staker] = time;
    }

    function updateRewardsClaimed(uint256 poolId, address staker, uint128 rewards) external {
        rewardsClaimed[poolId][staker] += rewards;
    }

    function updateRewardsDistributed(uint256 poolId, uint128 rewards) external {
        rewardsDistributed[poolId] += rewards;
    }

    function updateRewardsDistributedAt(uint40 time) external {
        rewardsDistributedAt = time;
    }
}
