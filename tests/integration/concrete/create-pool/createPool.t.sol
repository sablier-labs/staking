// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract CreatePool_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        warpStateTo(FEB_1_2025);

        // Set pool creator as the default caller for this test.
        setMsgSender(users.poolCreator);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            sablierStaking.createPool,
            (users.poolCreator, stakingToken, START_TIME, END_TIME, rewardToken, REWARD_AMOUNT)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_AdminZeroAddress() external whenNoDelegateCall {
        vm.expectRevert(Errors.SablierStaking_AdminZeroAddress.selector);
        sablierStaking.createPool({
            admin: address(0),
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_WhenStartTimeZero() external whenNoDelegateCall whenAdminNotZeroAddress {
        _test_CreatePool({ startTime: 0 });
    }

    function test_RevertWhen_StartTimeInPast()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
    {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StartTimeInPast.selector, FEB_1_2025 - 1));
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: FEB_1_2025 - 1,
            endTime: END_TIME,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_WhenStartTimeInPresent() external whenNoDelegateCall whenAdminNotZeroAddress whenStartTimeNotZero {
        _test_CreatePool({ startTime: getBlockTimestamp() });
    }

    function test_RevertWhen_EndTimeLessThanStartTime()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_StartTimeNotLessThanEndTime.selector, START_TIME, START_TIME - 1
            )
        );
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: START_TIME - 1,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_EndTimeEqualsStartTime()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
    {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StartTimeNotLessThanEndTime.selector, START_TIME, START_TIME)
        );
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: START_TIME,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_StakingTokenZeroAddress()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
    {
        vm.expectRevert(Errors.SablierStaking_StakingTokenZeroAddress.selector);
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: IERC20(address(0)),
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_RewardTokenZeroAddress()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
    {
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(0)));
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: IERC20(address(0)),
            rewardAmount: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_RewardAmountZero()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
        whenRewardTokenNotZeroAddress
    {
        vm.expectRevert(Errors.SablierStaking_RewardAmountZero.selector);
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            rewardAmount: 0
        });
    }

    function test_WhenRewardAmountNotZero()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotZero
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
        whenRewardTokenNotZeroAddress
    {
        _test_CreatePool({ startTime: START_TIME });
    }

    function _test_CreatePool(uint40 startTime) private {
        uint256 expectedPoolIds = sablierStaking.nextPoolId();

        // Set expected start time.
        uint40 expectedStartTime = startTime == 0 ? getBlockTimestamp() : startTime;

        // It should emit {Transfer} and {CreatePool} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.poolCreator, address(sablierStaking), REWARD_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.CreatePool({
            poolId: expectedPoolIds,
            admin: users.poolCreator,
            endTime: END_TIME,
            rewardToken: rewardToken,
            stakingToken: stakingToken,
            startTime: expectedStartTime,
            rewardAmount: REWARD_AMOUNT
        });

        // It should create the pool.
        uint256 actualPoolIds = sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: END_TIME,
            rewardToken: rewardToken,
            rewardAmount: REWARD_AMOUNT
        });

        // It should create the pool.
        assertEq(actualPoolIds, expectedPoolIds, "poolId");

        // It should bump the next Pool ID.
        assertEq(sablierStaking.nextPoolId(), expectedPoolIds + 1, "nextPoolId");

        // It should set the correct pool state.
        assertEq(sablierStaking.getAdmin(actualPoolIds), users.poolCreator, "admin");
        assertEq(sablierStaking.getStakingToken(actualPoolIds), stakingToken, "stakingToken");
        assertEq(sablierStaking.getStartTime(actualPoolIds), expectedStartTime, "startTime");
        assertEq(sablierStaking.getEndTime(actualPoolIds), END_TIME, "endTime");
        assertEq(sablierStaking.getRewardAmount(actualPoolIds), REWARD_AMOUNT, "rewardAmount");
    }
}
