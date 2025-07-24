// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRate_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertWhen_OutsideRewardsPeriod(uint40 timestamp) external whenNotNull {
        // Bound timestamp such that its outside the rewards period.
        vm.assume(timestamp < START_TIME || timestamp > END_TIME);

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

    function testFuzz_RewardRate(uint40 timestamp) external whenNotNull whenStartTimeNotInFuture whenEndTimeNotInPast {
        // Bound timestamp between the start and end times.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should return the correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
