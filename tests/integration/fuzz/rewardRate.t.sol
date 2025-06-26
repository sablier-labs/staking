// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRate_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RewardRate(uint40 timestamp) external whenNotNull {
        // Bound timestamp between the start and end times.
        timestamp = boundUint40(timestamp, FEB_1_2025, type(uint40).max);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should return the correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
