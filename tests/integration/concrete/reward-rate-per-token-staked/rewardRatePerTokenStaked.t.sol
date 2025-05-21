// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRatePerTokenStaked_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(staking.rewardRate, (campaignIds.nullCampaign));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.rewardRatePerTokenStaked(campaignIds.canceledCampaign);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull givenNotCanceled {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_EndTimeInPast() external whenNotNull givenNotCanceled whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
    }

    function test_GivenTotalStakedZero()
        external
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        warpStateTo(WARP_40_PERCENT);

        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = staking.rewardRatePerTokenStaked(campaignIds.freshCampaign);
        assertEq(actualRewardRatePerTokenStaked, 0, "reward rate per token staked");
    }

    function test_GivenTotalStakedNotZero()
        external
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        warpStateTo(WARP_40_PERCENT);

        // It should return correct reward rate per token staked.
        uint128 actualRewardRatePerTokenStaked = staking.rewardRatePerTokenStaked(campaignIds.defaultCampaign);
        uint128 expectedRewardRatePerTokenStaked = REWARD_RATE / TOTAL_AMOUNT_STAKED;
        assertEq(actualRewardRatePerTokenStaked, expectedRewardRatePerTokenStaked, "reward rate per token staked");
    }
}
