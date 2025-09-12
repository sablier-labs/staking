// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status, UserAccount } from "src/types/DataTypes.sol";

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
            sablierStaking.configureNextRound, (poolIds.defaultPool, START_TIME, END_TIME, REWARD_AMOUNT)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(
            sablierStaking.configureNextRound, (poolIds.nullPool, newStartTime, newEndTime, newRewardAmount)
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
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
    }

    function test_RevertWhen_EndTimeNotInPast() external whenNoDelegateCall whenNotNull whenCallerPoolAdmin {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInPast.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
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
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
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
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
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
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
    }

    function test_GivenAdminStaked()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
        whenNewStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
        whenNewRewardAmountNotZero
    {
        vm.warp(END_TIME - 1 seconds);
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
        vm.warp(END_TIME + 1 seconds);

        _test_ConfigureNextRound(true);
    }

    function test_GivenAdminNotStaked()
        external
        whenNoDelegateCall
        whenNotNull
        whenCallerPoolAdmin
        whenEndTimeInPast
        whenNewStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
        whenNewRewardAmountNotZero
    {
        _test_ConfigureNextRound(false);
    }

    function _test_ConfigureNextRound(bool adminStaked) private {
        (uint256 rptEarned, uint128 expectedUserRewards) = calculateLatestRewards(users.poolCreator);

        // If the admin has staked, it should emit a {SnapshotRewards} event.
        if (adminStaked) {
            vm.expectEmit({ emitter: address(sablierStaking) });
            emit ISablierStaking.SnapshotRewards(
                poolIds.defaultPool, END_TIME + 1 seconds, rptEarned, users.poolCreator, expectedUserRewards
            );
        }
        // It should emit {Transfer} and {ConfigureNextRound} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.poolCreator, address(sablierStaking), newRewardAmount);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ConfigureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);

        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);

        // If the admin has staked, it should update the admin's rewards snapshot.
        if (adminStaked) {
            UserAccount memory userAccount = sablierStaking.userAccount(poolIds.defaultPool, users.poolCreator);
            assertEq(userAccount.snapshotRptEarnedScaled, rptEarned, "snapshotRptEarnedScaled");
            assertEq(userAccount.snapshotRewards, expectedUserRewards, "snapshotRewards");
        }

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
