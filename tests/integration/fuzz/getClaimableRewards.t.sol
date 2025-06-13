// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

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

        (, uint128 expectedUserRewards) = calculateLatestRewards(caller);

        uint128 actualRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, caller);
        assertEq(actualRewards, expectedUserRewards, "rewards");
    }
}
