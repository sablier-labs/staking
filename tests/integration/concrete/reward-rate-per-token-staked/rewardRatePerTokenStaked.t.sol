// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRatePerTokenStaked_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
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
        sablierStaking.rewardRatePerTokenStaked(poolIds.defaultPool);
    }

    function test_RevertWhen_EndTimeInPast() external whenNotNull whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRatePerTokenStaked(poolIds.defaultPool);
    }

    function test_GivenTotalStakedZero() external view whenNotNull whenStartTimeNotInFuture whenEndTimeNotInPast {
        // It should return zero.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardRatePerTokenStaked(poolIds.freshPool);
        assertEq(actualRewardRatePerTokenStaked, 0, "reward rate per token staked");
    }

    function test_GivenTotalStakedNotZero() external view whenNotNull whenStartTimeNotInFuture whenEndTimeNotInPast {
        // It should return correct reward rate per token staked.
        uint128 actualRewardRatePerTokenStaked = sablierStaking.rewardRatePerTokenStaked(poolIds.defaultPool);
        uint128 expectedRewardRatePerTokenStaked = REWARD_RATE / TOTAL_STAKED;
        assertEq(actualRewardRatePerTokenStaked, expectedRewardRatePerTokenStaked, "reward rate per token staked");
    }
}
