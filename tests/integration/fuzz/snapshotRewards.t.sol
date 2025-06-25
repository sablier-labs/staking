// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract SnapshotRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertGiven_LastUpdateTimeNotLessThanEndTime(
        uint256 userSeed,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        givenStakedAmountNotZero
    {
        // Pick a user based on the seed.
        address user = userSeed % 2 == 0 ? users.recipient : users.staker;

        // Warp EVM state to the end time and take a snapshot so that last update time equals the end time.
        warpStateTo(END_TIME);
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, user);

        // Bound timestamp so that it is greater than or equal to the campaign end time.
        timestamp = boundUint40(timestamp, END_TIME, END_TIME + 365 days);

        // Forward time.
        vm.warp(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_SnapshotNotAllowed.selector, campaignIds.defaultCampaign, user, END_TIME
            )
        );

        stakingPool.snapshotRewards(campaignIds.defaultCampaign, user);
    }

    function testFuzz_SnapshotRewards(
        address caller,
        uint256 userSeed,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        givenStakedAmountNotZero
        givenLastUpdateTimeLessThanEndTime
    {
        assumeNoExcludedCallers(caller);

        // Bound timestamp so that it is greater than the campaign create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 1 days);

        // Pick a user based on the seed. Since users.recipient stakes at the start time of the campaign, skip it if
        // the fuzzed timestamp is before the start time.
        address user = userSeed % 2 == 0 && timestamp >= START_TIME ? users.recipient : users.staker;

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        (uint256 rewardsEarnedPerTokenScaled, uint128 rewards) = calculateLatestRewards(user);

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(stakingPool) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign, timestamp, rewardsEarnedPerTokenScaled, user, rewards
        );

        // Test snapshot rewards.
        setMsgSender(caller);
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, user);

        // It should update global rewards snapshot.
        (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            stakingPool.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(lastUpdateTime, timestamp, "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (lastUpdateTime, rewardsEarnedPerTokenScaled, rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, user);
        assertEq(lastUpdateTime, timestamp, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
