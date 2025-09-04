// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract SnapshotRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_GivenSnapshotTimeNotLessThanEndTime()
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
    {
        warpStateTo(END_TIME);

        // Update rewards so that the last update time is not less than the end time.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // Forward time.
        vm.warp(END_TIME + 1 days);

        (uint256 beforerptEarnedScaled, uint128 beforeRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        // It should do nothing.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint256 afterrptEarnedScaled, uint128 afterRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        assertEq(afterrptEarnedScaled, beforerptEarnedScaled, "rptEarnedScaled");
        assertEq(afterRewards, beforeRewards, "rewards");
    }

    function test_WhenEndTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
        givenSnapshotTimeLessThanEndTime
    {
        _test_SnapshotRewards();
    }

    function test_WhenEndTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
        givenSnapshotTimeLessThanEndTime
    {
        warpStateTo(END_TIME);

        _test_SnapshotRewards();
    }

    function test_WhenEndTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenStakedAmountNotZero
        givenSnapshotTimeLessThanEndTime
    {
        warpStateTo(END_TIME + 1);

        _test_SnapshotRewards();
    }

    /// @dev Shared function for testing.
    function _test_SnapshotRewards() private {
        (uint256 rptEarnedScaled, uint128 rewards) = calculateLatestRewards(users.recipient);

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, getBlockTimestamp(), rptEarnedScaled, users.recipient, rewards
        );

        // Update rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // It should update global rewards snapshot.
        (uint40 snapshotTime, uint256 snapshotRptDistributedScaled) =
            sablierStaking.globalRptAtSnapshot(poolIds.defaultPool);
        assertEq(snapshotTime, getBlockTimestamp(), "globalsnapshotTime");
        assertEq(snapshotRptDistributedScaled, rptEarnedScaled, "snapshotRptDistributedScaled");

        // It should update user rewards snapshot.
        (rptEarnedScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.recipient);
        assertEq(rptEarnedScaled, rptEarnedScaled, "rptEarnedScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
