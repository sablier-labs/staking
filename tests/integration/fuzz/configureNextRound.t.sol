// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Status } from "src/types/DataTypes.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ConfigureNextRound_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_RevertGiven_StatusACTIVE(
        uint40 newEndTime,
        uint40 newStartTime,
        uint128 newRewardAmount
    )
        external
        whenNotNull
        whenCallerPoolAdmin
        whenStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
    {
        // Assert that the status is ACTIVE.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ACTIVE, "status");

        // Bound new start time such that it is not in the past.
        newStartTime = boundUint40(newStartTime, getBlockTimestamp(), getBlockTimestamp() + 365 days);

        // Bound new end time such that it is greater than the new start time.
        newEndTime = boundUint40(newEndTime, newStartTime + 1 seconds, newStartTime + 365 days);

        // Bound new reward amount such that it is greater than 0.
        newRewardAmount = boundUint128(newRewardAmount, 1, MAX_UINT128);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInPast.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
    }

    function testFuzz_RevertGiven_StatusSCHEDULED(
        uint40 newEndTime,
        uint40 newStartTime,
        uint128 newRewardAmount
    )
        external
        whenNotNull
        whenCallerPoolAdmin
        whenStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
    {
        warpStateTo(END_TIME + 1 seconds);

        // Configure next round so that the status is SCHEDULED.
        configureNextRound();

        // Assert that the status is SCHEDULED.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.SCHEDULED, "status");

        // Bound new start time such that it is not in the past.
        newStartTime = boundUint40(newStartTime, getBlockTimestamp(), getBlockTimestamp() + 365 days);

        // Bound new end time such that it is greater than the new start time.
        newEndTime = boundUint40(newEndTime, newStartTime + 1 seconds, newStartTime + 365 days);

        // Bound new reward amount such that it is greater than 0.
        newRewardAmount = boundUint128(newRewardAmount, 1, MAX_UINT128);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_EndTimeNotInPast.selector, poolIds.defaultPool, END_TIME + 365 days
            )
        );
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);
    }

    function testFuzz_ConfigureNextRound_GivenStatusENDED(
        uint40 newEndTime,
        uint40 newStartTime,
        uint128 newRewardAmount
    )
        external
        whenNotNull
        whenCallerPoolAdmin
        whenStartTimeNotInPast
        whenNewEndTimeGreaterThanNewStartTime
    {
        warpStateTo(END_TIME + 1 seconds);

        // Assert that the status is ENDED.
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ENDED, "status");

        // Bound new start time such that it is not in the past.
        newStartTime = boundUint40(newStartTime, getBlockTimestamp(), getBlockTimestamp() + 365 days);

        // Bound new end time such that it is greater than the new start time.
        newEndTime = boundUint40(newEndTime, newStartTime + 1 seconds, newStartTime + 365 days);

        // Bound new reward amount such that it is greater than 0.
        newRewardAmount = boundUint128(newRewardAmount, 1, MAX_UINT128);

        // Deal tokens to the pool creator.
        deal({ token: address(rewardToken), to: users.poolCreator, give: newRewardAmount });
        rewardToken.approve(address(sablierStaking), newRewardAmount);

        // It should emit {Transfer} and {ConfigureNextRound} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.poolCreator, address(sablierStaking), newRewardAmount);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ConfigureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);

        // Configure next round.
        sablierStaking.configureNextRound(poolIds.defaultPool, newStartTime, newEndTime, newRewardAmount);

        // It should set the new start time.
        assertEq(sablierStaking.getStartTime(poolIds.defaultPool), newStartTime, "startTime");

        // It should set the new end time.
        assertEq(sablierStaking.getEndTime(poolIds.defaultPool), newEndTime, "endTime");

        // It should set the new reward amount.
        assertEq(sablierStaking.getRewardAmount(poolIds.defaultPool), newRewardAmount, "rewardAmount");

        // It should set the status to scheduled.
        Status expectedStatus = newStartTime == getBlockTimestamp() ? Status.ACTIVE : Status.SCHEDULED;
        assertEq(sablierStaking.status(poolIds.defaultPool), expectedStatus, "status");
    }
}
