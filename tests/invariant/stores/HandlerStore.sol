// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Status } from "src/types/DataTypes.sol";

/// @dev Storage variables needed for handlers.
contract HandlerStore {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Tracks all pools created by the invariant handler.
    uint256[] public poolIds;

    /// @dev Tracks the time when last snapshot is taken for all pools.
    uint40 public snapshotTime;

    /// @dev Tracks the amount of tokens staked by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint128 amount)) public amountStaked;

    /// @dev Maps stakers with the pool ID they have staked in.
    mapping(uint256 poolId => address[] stakers) public poolStakers;

    /// @dev Stores previous values for global rewards per token for each pool.
    mapping(uint256 poolId => uint256 rptScaled) public globalRptScaled;

    /// @dev Tracks the previous time global snapshot was taken for each pool.
    mapping(uint256 poolId => uint40 time) public globalSnapshotTime;

    /// @dev Tracks rewards claimed by each staker in each pool.
    mapping(uint256 poolId => mapping(address staker => uint256 rewards)) public rewardsClaimed;

    /// @dev Tracks rewards distribution period for each pool.
    mapping(uint256 poolId => uint40 rewards) public rewardDistributionPeriod;

    /// @dev Tracks the status of each pool.
    mapping(uint256 poolId => Status status) public status;

    /// @dev Tracks the total rewards deposited across all rounds for each pool.
    mapping(uint256 poolId => uint256 totalRewardsDeposited) public totalRewardsDeposited;

    /// @dev Stores previous values for user rewards per token for each pool.
    mapping(uint256 poolId => mapping(address staker => uint256 rptScaled)) public userRptScaled;

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

    function updateGlobalRptSnapshot(uint256 poolId, uint40 time, uint256 rptScaled) external {
        globalRptScaled[poolId] = rptScaled;
        globalSnapshotTime[poolId] = time;
    }

    function updateSnapshotTime(uint40 time) external {
        snapshotTime = time;
    }

    function updateStatus(uint256 poolId, Status currentStatus) external {
        status[poolId] = currentStatus;
    }

    function updateUserRptScaled(uint256 poolId, address staker, uint256 rptScaled) external {
        userRptScaled[poolId][staker] = rptScaled;
    }
}
