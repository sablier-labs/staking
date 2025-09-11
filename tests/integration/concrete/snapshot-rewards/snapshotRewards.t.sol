// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { UserAccount } from "src/types/DataTypes.sol";

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

        UserAccount memory beforeUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);

        // It should do nothing.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        UserAccount memory afterUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);

        assertEq(
            afterUserAccount.snapshotRptEarnedScaled,
            beforeUserAccount.snapshotRptEarnedScaled,
            "snapshotRptEarnedScaled"
        );
        assertEq(afterUserAccount.snapshotRewards, beforeUserAccount.snapshotRewards, "snapshotRewards");
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
            sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);
        assertEq(snapshotTime, getBlockTimestamp(), "globalSnapshotTime");
        assertEq(snapshotRptDistributedScaled, rptEarnedScaled, "snapshotRptDistributedScaled");

        // It should update user rewards snapshot.
        UserAccount memory userAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        assertEq(userAccount.snapshotRptEarnedScaled, rptEarnedScaled, "snapshotRptEarnedScaled");
        assertEq(userAccount.snapshotRewards, rewards, "snapshotRewards");
    }
}
