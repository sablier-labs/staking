// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRatePerTokenStaked_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertWhen_OutsideRewardsPeriod(uint40 timestamp) external whenNotNull {
        // Bound timestamp such that its outside the rewards period.
        vm.assume(timestamp < START_TIME || timestamp > END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_NotActive.selector, poolIds.defaultPool));
        sablierStaking.rewardRatePerTokenStaked(poolIds.defaultPool);
    }

    function testFuzz_RewardRatePerTokenStaked(uint40 timestamp)
        external
        whenNotNull
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
        givenTotalStakedNotZero
    {
        // Bound timestamp between the start and end times.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should return the correct reward rate per token staked.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardRatePerTokenStaked(poolIds.defaultPool);
        uint128 expectedRewardRatePerTokenStaked = REWARD_RATE / TOTAL_STAKED;
        assertEq(actualRewardRatePerTokenStaked, expectedRewardRatePerTokenStaked, "reward rate per token staked");
    }
}
