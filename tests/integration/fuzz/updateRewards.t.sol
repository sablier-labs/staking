// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract UpdateRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_GivenLastUpdateTimeNotLessThanEndTime(
        uint256 userSeed,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
    {
        // Pick a user based on the seed.
        address user = userSeed % 2 == 0 ? users.recipient : users.staker;

        // Warp EVM state to the end time and update rewards so that last update time equals the end time.
        warpStateTo(END_TIME);
        sablierStaking.updateRewards(poolIds.defaultPool, user);

        // Bound timestamp so that it is greater than or equal to the end time.
        timestamp = boundUint40(timestamp, END_TIME, END_TIME + 365 days);

        // Forward time.
        vm.warp(timestamp);

        (uint256 beforeRewardsEarnedPerTokenScaled, uint128 beforeRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, user);

        // It should do nothing.
        sablierStaking.updateRewards(poolIds.defaultPool, user);

        (uint256 afterRewardsEarnedPerTokenScaled, uint128 afterRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, user);

        assertEq(afterRewardsEarnedPerTokenScaled, beforeRewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(afterRewards, beforeRewards, "rewards");
    }

    function testFuzz_UpdateRewards(
        address caller,
        uint256 userSeed,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
        givenLastUpdateTimeLessThanEndTime
    {
        assumeNoExcludedCallers(caller);

        // Bound timestamp so that it is greater than the create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 1 days);

        // Pick a user based on the seed. Since users.recipient stakes at the start time of the pool, skip it if
        // the fuzzed timestamp is before the start time.
        address user = userSeed % 2 == 0 && timestamp >= START_TIME ? users.recipient : users.staker;

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        (uint256 rewardsEarnedPerTokenScaled, uint128 rewards) = calculateLatestRewards(user);

        // It should emit {UpdateRewards} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UpdateRewards(poolIds.defaultPool, timestamp, rewardsEarnedPerTokenScaled, user, rewards);

        // Update rewards.
        setMsgSender(caller);
        sablierStaking.updateRewards(poolIds.defaultPool, user);

        // It should update global rewards distributed per token.
        (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalRewardsPerTokenSnapshot(poolIds.defaultPool);
        assertEq(lastUpdateTime, timestamp, "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards.
        (rewardsEarnedPerTokenScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, user);
        assertEq(rewardsEarnedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
