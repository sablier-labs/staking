// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRate_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertWhen_StartTimeInFuture(uint40 timestamp) external whenNotNull givenNotClosed {
        // Bound timestamp such that the start time is in the future.
        timestamp = boundUint40(timestamp, 0, START_TIME - 1);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function testFuzz_RevertWhen_EndTimeInPast(uint40 timestamp) external whenNotNull givenNotClosed {
        // Bound timestamp such that the end time is in the past.
        timestamp = boundUint40(timestamp, END_TIME + 1, type(uint40).max);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function testFuzz_RewardRate(uint40 timestamp)
        external
        whenNotNull
        givenNotClosed
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        // Bound timestamp between the start and end times.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should return the correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
