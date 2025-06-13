// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract CreateCampaign_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        warpStateTo(FEB_1_2025);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(
            staking.createCampaign,
            (users.campaignCreator, stakingToken, START_TIME, END_TIME, rewardToken, REWARD_AMOUNT)
        );
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_AdminZeroAddress() external whenNoDelegateCall {
        vm.expectRevert(Errors.SablierStaking_AdminZeroAddress.selector);
        staking.createCampaign({
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
        staking.createCampaign({
            admin: users.campaignCreator,
            stakingToken: stakingToken,
            startTime: FEB_1_2025 - 1,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    function test_WhenStartTimeInPresent() external whenNoDelegateCall whenAdminNotZeroAddress {
        uint40 currentTime = getBlockTimestamp();

        uint256 expectedCampaignId = staking.nextCampaignId();

        // It should emit {Transfer} and {CreateCampaign} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.campaignCreator, address(staking), REWARD_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.CreateCampaign(
            expectedCampaignId, users.campaignCreator, stakingToken, rewardToken, currentTime, END_TIME, REWARD_AMOUNT
        );

        // It should create the campaign.
        uint256 actualCampaignId = staking.createCampaign({
            admin: users.campaignCreator,
            stakingToken: stakingToken,
            startTime: currentTime,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the campaign.
        assertEq(actualCampaignId, expectedCampaignId, "campaignId");

        // It should bump the next campaign ID.
        assertEq(staking.nextCampaignId(), expectedCampaignId + 1, "nextCampaignId");
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
        staking.createCampaign({
            admin: users.campaignCreator,
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
        staking.createCampaign({
            admin: users.campaignCreator,
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
        staking.createCampaign({
            admin: users.campaignCreator,
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
        staking.createCampaign({
            admin: users.campaignCreator,
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
        staking.createCampaign({
            admin: users.campaignCreator,
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
        uint256 expectedCampaignId = staking.nextCampaignId();

        // It should emit {Transfer} and {CreateCampaign} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(users.campaignCreator, address(staking), REWARD_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.CreateCampaign(
            expectedCampaignId, users.campaignCreator, stakingToken, rewardToken, START_TIME, END_TIME, REWARD_AMOUNT
        );

        // It should create the campaign.
        uint256 actualCampaignId = staking.createCampaign({
            admin: users.campaignCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });

        // It should create the campaign.
        assertEq(actualCampaignId, expectedCampaignId, "campaignId");

        // It should bump the next campaign ID.
        assertEq(staking.nextCampaignId(), expectedCampaignId + 1, "nextCampaignId");

        // It should set the correct campaign state.
        assertEq(staking.getAdmin(actualCampaignId), users.campaignCreator, "admin");
        assertEq(staking.getStakingToken(actualCampaignId), stakingToken, "stakingToken");
        assertEq(staking.getStartTime(actualCampaignId), START_TIME, "startTime");
        assertEq(staking.getEndTime(actualCampaignId), END_TIME, "endTime");
        assertEq(staking.getRewardToken(actualCampaignId), rewardToken, "rewardToken");
        assertEq(staking.getTotalRewards(actualCampaignId), REWARD_AMOUNT, "totalRewards");
        assertEq(staking.wasCanceled(actualCampaignId), false, "wasCanceled");
    }
}
