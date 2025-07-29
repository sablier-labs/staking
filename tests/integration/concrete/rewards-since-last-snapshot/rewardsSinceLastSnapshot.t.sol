// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardsSinceLastSnapshot_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.rewardsSinceLastSnapshot, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_GivenTotalStakedZero() external view whenNotNull {
        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardsSinceLastSnapshot(poolIds.freshPool);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeNotLessThanEndTime() external whenNotNull givenTotalStakedNotZero {
        warpStateTo(END_TIME);

        // Snapshot rewards so that last time update equals end time.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardsSinceLastSnapshot(poolIds.defaultPool);
        assertEq(actualRewardRatePerTokenStaked, 0, "rewardsSinceLastSnapshot");
    }

    function test_GivenLastUpdateTimeLessThanEndTime() external whenNotNull givenTotalStakedNotZero {
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
