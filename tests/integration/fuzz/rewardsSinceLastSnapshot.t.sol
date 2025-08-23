// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardsSinceLastSnapshot_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RewardsSinceLastSnapshot_GivenLastTimeUpdateNotLessThanEndTime(uint40 timestamp)
        external
        whenNotNull
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        // Bound timestamp such that last time update is greater than or equal to end time.
        timestamp = boundUint40(timestamp, END_TIME, END_TIME + 30 days);

        // Warp the EVM state to the given timestamp and take snapshot.
        warpStateTo(timestamp);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // Bound timestamp to a new value which is greater than the current block time.
        timestamp = boundUint40(timestamp, getBlockTimestamp() + 1, END_TIME + 365 days);

        vm.warp(timestamp);

        // It should return zero.
        uint128 actualRewardsSinceLastSnapshot = sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
        assertEq(actualRewardsSinceLastSnapshot, 0, "rewardsSinceLastSnapshot");
    }

    function testFuzz_RewardsSinceLastSnapshot(uint40 timestamp)
        external
        whenNotNull
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        // Bound timestamp such that last time update is less than end time.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME - 1);

        // Warp the EVM state to the given timestamp and snapshot rewards.
        warpStateTo(timestamp);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // Bound timestamp to a new value which is greater than the current block time.
        timestamp = boundUint40(timestamp, getBlockTimestamp() + 1, END_TIME + 365 days);

        uint128 expectedRewardsSinceLastSnapshot;
        if (timestamp > END_TIME) {
            expectedRewardsSinceLastSnapshot = REWARD_AMOUNT * (END_TIME - getBlockTimestamp()) / REWARD_PERIOD;
        } else {
            expectedRewardsSinceLastSnapshot = REWARD_AMOUNT * (timestamp - getBlockTimestamp()) / REWARD_PERIOD;
        }

        vm.warp(timestamp);

        // It should return correct rewards per token since last snapshot.
        uint128 actualRewardsSinceLastSnapshot = sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
        assertEq(actualRewardsSinceLastSnapshot, expectedRewardsSinceLastSnapshot, "rewardsSinceLastSnapshot");
    }
}
