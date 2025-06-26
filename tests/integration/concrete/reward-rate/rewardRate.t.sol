// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRate_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.rewardRate, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_WhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        // It should return correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }

    function test_WhenEndTimeInPast() external whenNotNull whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);

        // It should return correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }

    function test_WhenEndTimeNotInPast() external view whenNotNull whenStartTimeNotInFuture {
        // It should return correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
