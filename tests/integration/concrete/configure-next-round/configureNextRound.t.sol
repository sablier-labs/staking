// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ConfigureNextRound_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    uint40 internal newEndTime = END_TIME + 365 days;
    uint40 internal newStartTime = END_TIME + 10 days;
    uint128 internal newRewardAmount = REWARD_AMOUNT;

    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        // Warp EVM state to 1 second after the end time.
        warpStateTo(END_TIME + 1 seconds);

        setMsgSender(users.poolCreator);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            sablierStaking.configureNextRound, (poolIds.defaultPool, END_TIME, START_TIME, REWARD_AMOUNT)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(
            sablierStaking.configureNextRound, (poolIds.nullPool, newEndTime, newStartTime, newRewardAmount)
        );
        expectRevert_Null(callData);
    }

    function test_RevertWhen_CallerNotPoolAdmin() external whenNoDelegateCall whenNotNull {
        setMsgSender(users.eve);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotPoolAdmin.selector, poolIds.defaultPool, users.eve, users.poolCreator
            )
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);
    }

    function test_RevertWhen_EndTimeNotInPast() external whenNoDelegateCall whenNotNull whenCallerPoolAdmin {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInPast.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);
    }

    function test_RevertWhen_NewStartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
    {
        newStartTime = END_TIME;

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StartTimeInPast.selector, newStartTime));
        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);
    }

    function test_RevertWhen_NewEndTimeNotGreaterThanNewStartTime()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
        whenNewStartTimeNotInPast
    {
        newEndTime = newStartTime - 1;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StartTimeNotLessThanEndTime.selector, newStartTime, newEndTime)
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);
    }

    function test_RevertWhen_NewRewardAmountZero()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
        whenNewStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
    {
        newRewardAmount = 0;

        vm.expectRevert(Errors.SablierStaking_RewardAmountZero.selector);
        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);
    }

    function test_WhenNewRewardAmountNotZero()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
        whenNewStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
    {
        // It should emit {UpdateRewards}, {Transfer} and {ConfigureNextRound} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UpdateRewards(
            poolIds.defaultPool,
            END_TIME + 1 seconds,
            REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME_SCALED,
            users.poolCreator,
            0
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.poolCreator, address(sablierStaking), newRewardAmount);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ConfigureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);

        sablierStaking.configureNextRound(poolIds.defaultPool, newEndTime, newStartTime, newRewardAmount);

        // It should set the new start time.
        assertEq(sablierStaking.getStartTime(poolIds.defaultPool), newStartTime, "startTime");

        // It should set the new end time.
        assertEq(sablierStaking.getEndTime(poolIds.defaultPool), newEndTime, "endTime");

        // It should set the new reward amount.
        assertEq(sablierStaking.getRewardAmount(poolIds.defaultPool), newRewardAmount, "rewardAmount");

        // It should set the status to scheduled.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.SCHEDULED, "status");
    }
}
