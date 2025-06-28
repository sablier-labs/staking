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

    /// @dev In a pool, total rewards distributed should be equal to the sum of total rewards claimed by all users and
    /// total claimable rewards of all users.
    function invariant_TotalRewardsDistributed() external view {
        // Loop through all pools.
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            uint128 actualRewardsEarnedByAllStakers = 0;
            uint256 totalStakers = handlerStore.totalStakers(poolId);
            for (uint256 j = 0; j < totalStakers; ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                uint128 rewardsClaimed = handlerStore.rewardsClaimed(poolId, staker);
                uint128 claimableRewards = sablierStaking.claimableRewards(poolId, staker);
                uint128 totalRewardsEarnedByUser = rewardsClaimed + claimableRewards;
                actualRewardsEarnedByAllStakers += totalRewardsEarnedByUser;
            }

            uint128 poolRewards = sablierStaking.getTotalRewards(poolId);
            uint128 totalRewardsPeriod = sablierStaking.getEndTime(poolId) - sablierStaking.getStartTime(poolId);
            uint128 expectedRewardsDistributed =
                poolRewards * handlerStore.rewardDistributionPeriod(poolId) / totalRewardsPeriod;

            // Because of the division in the calculation of `rewardsDistributed` in the BaseHandler, there could be a
            // small difference between the actual and expected rewards distributed. Therefore, we use an error
            // percentage of 5% to account for the precision loss.
            assertApproxEqRel(
                actualRewardsEarnedByAllStakers,
                expectedRewardsDistributed,
                5e18,
                "Invariant violation: total rewards distributed != rewardsClaimed + claimableRewards +/- 5%"
            );
            assertGe(expectedRewardsDistributed, actualRewardsEarnedByAllStakers);
        }
    }
}
