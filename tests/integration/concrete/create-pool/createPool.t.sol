// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_StartTimeInPast() external whenNoDelegateCall whenAdminNotZeroAddress {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StartTimeInPast.selector, FEB_1_2025 - 1));
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: FEB_1_2025 - 1,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_WhenStartTimeInPresent() external whenNoDelegateCall whenAdminNotZeroAddress {
        uint40 currentTime = getBlockTimestamp();

        uint256 expectedPoolIds = sablierStaking.nextPoolId();

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
            startTime: currentTime,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the pool.
        uint256 actualPoolIds = sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: currentTime,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the pool.
        assertEq(actualPoolIds, expectedPoolIds, "poolId");

        // It should bump the next Pool ID.
        assertEq(sablierStaking.nextPoolId(), expectedPoolIds + 1, "nextPoolId");
    }

    function test_RevertWhen_EndTimeLessThanStartTime()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeInFuture
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_EndTimeNotGreaterThanStartTime.selector, START_TIME, START_TIME - 1
            )
        );
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: START_TIME - 1,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_EndTimeEqualsStartTime()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeInFuture
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_EndTimeNotGreaterThanStartTime.selector, START_TIME, START_TIME
            )
        );
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: START_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_StakingTokenZeroAddress()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
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
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_RewardTokenZeroAddress()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
    {
        vm.expectRevert(Errors.SablierStaking_RewardTokenZeroAddress.selector);
        sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: IERC20(address(0)),
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_RevertWhen_TotalRewardsZero()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
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
            totalRewards: 0
        });
    }

    function test_WhenTotalRewardsNotZero()
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeInFuture
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
        whenRewardTokenNotZeroAddress
    {
        uint256 expectedPoolIds = sablierStaking.nextPoolId();

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
            startTime: START_TIME,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the pool.
        uint256 actualPoolIds = sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the pool.
        assertEq(actualPoolIds, expectedPoolIds, "poolId");

        // It should bump the next Pool ID.
        assertEq(sablierStaking.nextPoolId(), expectedPoolIds + 1, "nextPoolId");

        // It should set the correct pool state.
        assertEq(sablierStaking.getAdmin(actualPoolIds), users.poolCreator, "admin");
        assertEq(sablierStaking.getStakingToken(actualPoolIds), stakingToken, "stakingToken");
        assertEq(sablierStaking.getStartTime(actualPoolIds), START_TIME, "startTime");
        assertEq(sablierStaking.getEndTime(actualPoolIds), END_TIME, "endTime");
        assertEq(sablierStaking.getTotalRewards(actualPoolIds), REWARD_AMOUNT, "totalRewards");
    }
}
