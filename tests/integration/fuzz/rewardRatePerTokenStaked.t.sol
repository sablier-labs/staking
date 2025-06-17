// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRatePerTokenStaked_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertWhen_StartTimeInFuture(uint40 timestamp) external whenNotNull givenNotCanceled {
        // Bound timestamp such that the start time is in the future.
        timestamp = boundUint40(timestamp, 0, START_TIME - 1);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
    }

    function testFuzz_RevertWhen_EndTimeInPast(uint40 timestamp) external whenNotNull givenNotCanceled {
        // Bound timestamp such that the end time is in the past.
        timestamp = boundUint40(timestamp, END_TIME + 1, type(uint40).max);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
    }

    function testFuzz_RewardRatePerTokenStaked(uint40 timestamp)
        external
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
        givenTotalStakedNotZero
    {
        // Bound timestamp between the start and end times.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should return the correct reward rate per token staked.
        uint128 actualRewardRatePerTokenStaked = staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
        uint128 expectedRewardRatePerTokenStaked = REWARD_RATE / TOTAL_STAKED;
        assertEq(actualRewardRatePerTokenStaked, expectedRewardRatePerTokenStaked, "reward rate per token staked");
    }
}
