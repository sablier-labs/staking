// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ClaimableRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_ClaimableRewards(
        bool isRecipient,
        uint40 timestamp
    )
        external
        whenNotNull
        whenUserNotZeroAddress
        givenClaimableRewardsNotZero
    {
        // Bound caller to either be recipient or staker.
        address caller = isRecipient ? users.recipient : users.staker;

        // Bound timestamp such that the start time is in the past.
        timestamp = boundUint40(timestamp, START_TIME + 1, END_TIME + 1 days);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        (, uint256 expectedUserRewardsScaled) = calculateLatestRewardsScaled(caller);

        uint128 actualRewards = sablierStaking.claimableRewards(poolIds.defaultPool, caller);
        uint128 expectedRewards = getDescaledValue(expectedUserRewardsScaled);
        assertEq(actualRewards, expectedRewards, "rewards");
    }
}
