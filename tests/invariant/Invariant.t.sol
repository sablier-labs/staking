// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { StdInvariant } from "forge-std/src/StdInvariant.sol";

import { Base_Test } from "../Base.t.sol";
import { StakingHandler } from "./handlers/StakingHandler.sol";
import { HandlerStore } from "./stores/HandlerStore.sol";

contract Invariant_Test is Base_Test, StdInvariant {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    StakingHandler public stakingHandler;
    HandlerStore public handlerStore;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Base_Test.setUp();

        // Deploy the handlers and the associated store.
        handlerStore = new HandlerStore();
        stakingHandler = new StakingHandler(handlerStore, sablierStaking, tokens);

        // Label the contracts.
        vm.label({ account: address(handlerStore), newLabel: "handlerStore" });
        vm.label({ account: address(stakingHandler), newLabel: "stakingHandler" });

        // Target the staking handler for invariant testing.
        targetContract(address(stakingHandler));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(handlerStore));
        excludeSender(address(sablierStaking));
        excludeSender(address(stakingHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                              UNCONDITIONAL INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The `nextPoolId` should always equal the current pool ID + 1.
    function invariant_NextPoolId() external view {
        if (handlerStore.totalPools() == 0) {
            return;
        }

        uint256 lastPoolId = handlerStore.lastPoolId();
        uint256 nextPoolId = sablierStaking.nextPoolId();
        assertEq(nextPoolId, lastPoolId + 1, "Invariant violation: next pool ID not incremented");
    }

    /// @dev In a pool, the sum of total rewards claimed by all users and total claimable rewards of all users should
    /// never exceed the expected rewards calculated without performing more than 1 division.
    function invariant_TotalRewardsDistributedEqUserRewards() external view {
        // Loop through all pools.
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            uint128 rewardsEarnedByAllStakers = _actualRewardsEarnedByAllStakers(poolId);

            uint128 poolRewards = sablierStaking.getTotalRewards(poolId);
            uint128 totalRewardsPeriod = sablierStaking.getEndTime(poolId) - sablierStaking.getStartTime(poolId);
            uint128 expectedRewardsDistributed =
                poolRewards * handlerStore.rewardDistributionPeriod(poolId) / totalRewardsPeriod;

            // Because of the difference between the calculation of `expectedRewardsDistributed` and the actual rewards
            // earned by all stakers, there could be a small difference. Therefore, we use an error percentage of 5% to
            // account for the precision loss. Important bit is that the actual rewards earned by all stakers should
            // never exceed the expected rewards distributed, because the latter uses more precise calculations.
            assertApproxEqRel(
                rewardsEarnedByAllStakers,
                expectedRewardsDistributed,
                5e18,
                "Invariant violation: total rewards distributed != rewardsClaimed + claimableRewards +/- 5%"
            );
            assertLe(
                rewardsEarnedByAllStakers,
                expectedRewardsDistributed,
                "Invariant violation: rewardsClaimed + claimableRewards > total rewards distributed"
            );
        }
    }

    /// @dev The sum of total rewards claimed by all users and total claimable rewards of all users should never exceed
    /// `pool.totalRewards`.
    function invariant_UserRewardsLePoolRewards() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint128 rewardsEarnedByAllStakers = _actualRewardsEarnedByAllStakers(poolId);
            uint128 poolRewards = sablierStaking.getTotalRewards(poolId);

            assertLe(
                rewardsEarnedByAllStakers,
                poolRewards,
                "Invariant violation: rewardsClaimed + claimableRewards > total rewards distributed"
            );
        }
    }

    /// @dev Global rewards distributed per token and snapshot time should never decrease over time.
    function invariant_GlobalRewardsPerTokenNeverDecrease() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            (uint40 snapshotTime, uint256 currentRewardsPerToken) = sablierStaking.globalSnapshot(poolId);
            uint40 previousSnapshotTime = handlerStore.globalSnapshotTime(poolId);
            uint256 previousRewardsPerToken = handlerStore.globalRewardsPerTokenScaled(poolId);

            assertGe(snapshotTime, previousSnapshotTime, "Invariant violation: global snapshot time decreased");

            assertGe(
                currentRewardsPerToken,
                previousRewardsPerToken,
                "Invariant violation: global rewards per token decreased"
            );
        }
    }

    /// @dev For any user in a pool, rewards earned per token and snapshot time should never decrease over time.
    function invariant_UserRewardsPerTokenNeverDecrease() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                (uint40 snapshotTime, uint256 currentRewardsPerToken,) = sablierStaking.userSnapshot(poolId, staker);
                uint40 previousSnapshotTime = handlerStore.userSnapshotTime(poolId, staker);
                uint256 previousRewardsPerToken = handlerStore.userRewardsPerTokenScaled(poolId, staker);

                assertGe(snapshotTime, previousSnapshotTime, "Invariant violation: user snapshot time decreased");

                assertGe(
                    currentRewardsPerToken,
                    previousRewardsPerToken,
                    "Invariant violation: user rewards per token decreased"
                );
            }
        }
    }

    /// @dev For any user in a pool, rewards earned per tokens should never exceed global rewards distributed per token.
    function invariant_UserRewardsPerTokenLeGlobalRewardsPerToken() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            (, uint256 globalRewardsPerToken) = sablierStaking.globalSnapshot(poolId);

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                (, uint256 userRewardsPerToken,) = sablierStaking.userSnapshot(poolId, staker);

                assertLe(
                    userRewardsPerToken,
                    globalRewardsPerToken,
                    "Invariant violation: user rewards per token > global rewards per token"
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Private function to calculate the rewards earned by all stakers in a given pool.
    function _actualRewardsEarnedByAllStakers(uint256 poolId) internal view returns (uint128 rewards) {
        uint256 totalStakers = handlerStore.totalStakers(poolId);
        for (uint256 i = 0; i < totalStakers; ++i) {
            address staker = handlerStore.poolStakers(poolId, i);
            uint128 rewardsClaimed = handlerStore.rewardsClaimed(poolId, staker);
            uint128 claimableRewards = sablierStaking.claimableRewards(poolId, staker);
            uint128 totalRewardsEarnedByUser = rewardsClaimed + claimableRewards;
            rewards += totalRewardsEarnedByUser;
        }
    }
}
