// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract RewardRate_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.rewardRate, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Closed() external whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.rewardRate(poolIds.closedPool);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNotNull givenNotClosed {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function test_RevertWhen_EndTimeInPast() external whenNotNull givenNotClosed whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStakingState_OutsideRewardsPeriod.selector, poolIds.defaultPool, START_TIME, END_TIME
            )
        );
        sablierStaking.rewardRate(poolIds.defaultPool);
    }

    function test_GivenTotalStakedZero()
        external
        view
        whenNotNull
        givenNotClosed
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        // It should return zero.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.freshPool);
        assertEq(actualRewardRate, 0, "reward rate");
    }

    function test_GivenTotalStakedNotZero()
        external
        view
        whenNotNull
        givenNotClosed
        whenStartTimeNotInFuture
        whenEndTimeNotInPast
    {
        // It should return correct reward rate.
        uint128 actualRewardRate = sablierStaking.rewardRate(poolIds.defaultPool);
        assertEq(actualRewardRate, REWARD_RATE, "reward rate");
    }
}
