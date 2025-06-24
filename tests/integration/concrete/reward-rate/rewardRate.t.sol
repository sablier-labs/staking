// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRate_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(staking.rewardRate, (campaignIds.nullCampaign));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.rewardRate(campaignIds.canceledCampaign);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull givenNotCanceled {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRate(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_EndTimeInPast() external whenNotNull givenNotCanceled whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_CampaignNotActive.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardRate(campaignIds.defaultCampaign);
    }

    function test_GivenTotalStakedZero()
        external
        view
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        // It should return zero.
        uint128 actualRewardRate = staking.rewardRate(campaignIds.freshCampaign);
        assertEq(actualRewardRate, 0, "reward rate");
    }

    function test_GivenTotalStakedNotZero()
        external
        view
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        // It should return correct reward rate.
        uint128 actualRewardRate = staking.rewardRate(campaignIds.defaultCampaign);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
