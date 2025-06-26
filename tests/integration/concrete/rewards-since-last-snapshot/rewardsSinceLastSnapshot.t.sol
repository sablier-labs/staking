// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardsSinceLastSnapshot_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.rewardsSinceLastSnapshot, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Closed() external whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.rewardsSinceLastSnapshot(poolIds.closedPool);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull givenNotClosed {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_StartTimeInFuture.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
    }

    function test_GivenTotalStakedZero() external view whenNotNull givenNotClosed whenStartTimeNotInFuture {
        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardsSinceLastSnapshot(poolIds.freshPool);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeNotLessThanEndTime()
        external
        whenNotNull
        givenNotClosed
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        warpStateTo(END_TIME);

        // Snapshot rewards so that last time update equals end time.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeLessThanEndTime()
        external
        whenNotNull
        givenNotClosed
        whenStartTimeNotInFuture
        givenTotalStakedNotZero
    {
        warpStateTo(END_TIME);

        // It should return correct rewards per token since last snapshot.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
        assertEq(
            actualRewardRatePerTokenStaked,
            REWARDS_DISTRIBUTED_END_TIME - REWARDS_DISTRIBUTED,
            "rewardsSinceLastSnapshot"
        );
    }
}
