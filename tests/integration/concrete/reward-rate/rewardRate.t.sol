// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRate_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.rewardRate, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function test_RevertWhen_EndTimeInPast() external whenNotNull whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function test_WhenEndTimeNotInPast() external view whenNotNull whenStartTimeNotInFuture {
        // It should return correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
