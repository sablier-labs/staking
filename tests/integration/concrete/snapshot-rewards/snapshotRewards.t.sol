// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract SnapshotRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.snapshotRewards, (poolIds.defaultPool, users.recipient));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.snapshotRewards, (poolIds.nullPool, users.recipient));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_StakedAmountZero() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_NoStakedAmount.selector, poolIds.defaultPool, users.eve)
        );
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.eve);
    }

    function test_WhenEndTimeInFuture() external whenNoDelegateCall whenNotNull givenStakedAmountNotZero {
        _test_SnapshotRewards();
    }

    function test_WhenEndTimeInPresent() external whenNoDelegateCall whenNotNull givenStakedAmountNotZero {
        warpStateTo(END_TIME);

        _test_SnapshotRewards();
    }

    function test_WhenEndTimeInPast() external whenNoDelegateCall whenNotNull givenStakedAmountNotZero {
        warpStateTo(END_TIME + 1);

        _test_SnapshotRewards();
    }

    /// @dev Shared function for testing.
    function _test_SnapshotRewards() private {
        (uint256 rewardsEarnedPerTokenScaled, uint128 rewards) = calculateLatestRewards(users.recipient);

        // It should emit {SnapshotRewards} event.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, getBlockTimestamp(), rewardsEarnedPerTokenScaled, users.recipient, rewards
        );

        // Snapshot user rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // It should update global rewards snapshot.
        (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(lastUpdateTime, getBlockTimestamp(), "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (rewardsEarnedPerTokenScaled, rewards) = sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);
        assertEq(rewardsEarnedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
