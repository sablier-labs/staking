// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Amounts } from "src/types/DataTypes.sol";
import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract GetClaimableRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_GetClaimableRewards(
        bool isRecipient,
        uint40 timestamp
    )
        external
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        whenClaimableRewardsNotZero
    {
        // Bound caller to either be recipient or staker.
        address caller = isRecipient ? users.recipient : users.staker;

        // Bound timestamp such that the start time is in the past.
        timestamp = boundUint40(timestamp, START_TIME + 1, END_TIME + 1 days);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        uint128 totalAmountStaked = staking.totalAmountStaked(campaignIds.defaultCampaign);
        (uint40 lastTimeUpdate, uint256 globalRewardsPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);

        // Calculate time elapsed since last global snapshot.
        uint40 timeElapsed = timestamp >= END_TIME ? END_TIME - lastTimeUpdate : timestamp - lastTimeUpdate;

        // Calculate expected rewards.
        uint128 rewardsSinceLastUpdate = REWARD_AMOUNT * timeElapsed / CAMPAIGN_DURATION;

        uint256 expectedRewardsPerTokenScaled =
            globalRewardsPerTokenScaled + getScaledValue(rewardsSinceLastUpdate) / totalAmountStaked;

        (, uint256 userRewardsPerTokenScaled, uint128 rewardsAtLastUserSnapshot) =
            staking.userSnapshot(campaignIds.defaultCampaign, caller);

        Amounts memory amounts = staking.amountStakedByUser(campaignIds.defaultCampaign, caller);
        uint128 expectedUserRewards = rewardsAtLastUserSnapshot
            + getDescaledValue((expectedRewardsPerTokenScaled - userRewardsPerTokenScaled) * amounts.totalAmountStaked);

        uint128 actualRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, caller);
        assertEq(actualRewards, expectedUserRewards, "rewards");
    }
}
