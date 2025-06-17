// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardsPerTokenSinceLastSnapshot_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(staking.rewardsPerTokenSinceLastSnapshot, (campaignIds.nullCampaign));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.rewardsPerTokenSinceLastSnapshot(campaignIds.canceledCampaign);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull givenNotCanceled {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignNotStarted.selector, campaignIds.defaultCampaign, START_TIME, END_TIME
            )
        );
        staking.rewardsPerTokenSinceLastSnapshot(campaignIds.defaultCampaign);
    }

    function test_GivenTotalStakedZero() external view whenNotNull givenNotCanceled whenStartTimeNotInFuture {
        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = staking.rewardsPerTokenSinceLastSnapshot(campaignIds.freshCampaign);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsPerTokenSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeNotLessThanEndTime()
        external
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        warpStateTo(END_TIME);

        // Snapshot rewards so that last time update equals end time.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = staking.rewardsPerTokenSinceLastSnapshot(campaignIds.defaultCampaign);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsPerTokenSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeLessThanEndTime()
        external
        whenNotNull
        givenNotCanceled
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        warpStateTo(END_TIME);

        // It should return correct rewards per token since last snapshot.
        uint128 actualRewardRatePerTokenStaked = staking.rewardsPerTokenSinceLastSnapshot(campaignIds.defaultCampaign);
        assertEq(
            actualRewardRatePerTokenStaked,
            REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME - REWARDS_DISTRIBUTED_PER_TOKEN,
            "rewardsPerTokenSinceLastSnapshot"
        );
    }
}
