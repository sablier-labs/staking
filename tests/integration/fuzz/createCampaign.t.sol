// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract CreateCampaign_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should return the correct reward rate when the campaign is active.
    /// - It should revert when the campaign is inactive.
    function testFuzz_createCampaign(
        address admin,
        address campaignCreator,
        uint40 endTime,
        uint40 startTime,
        uint128 totalRewards
    )
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotInPast
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
        whenRewardTokenNotZeroAddress
        whenTotalRewardsNotZero
    {
        // Ensure the parameters are within constraints.
        vm.assume(admin != address(0) && campaignCreator != address(0));
        vm.assume(startTime >= getBlockTimestamp() && startTime < endTime);
        vm.assume(totalRewards > 0);

        // Deal reward token to the campaign creator.
        deal({ token: address(rewardToken), to: campaignCreator, give: totalRewards });
        approveContract(address(rewardToken), campaignCreator, address(staking));

        // Set the campaign creator as the caller.
        setMsgSender(campaignCreator);

        uint256 expectedCampaignId = staking.nextCampaignId();

        // It should emit {Transfer} and {CreateCampaign} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(campaignCreator, address(staking), totalRewards);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.CreateCampaign(
            expectedCampaignId, campaignCreator, dai, rewardToken, startTime, endTime, totalRewards
        );

        // Create the campaign.
        uint256 actualCampaignId = staking.createCampaign({
            admin: campaignCreator,
            stakingToken: dai,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: totalRewards
        });

        // It should create the campaign.
        assertEq(actualCampaignId, expectedCampaignId, "campaignId");

        // It should bump the next campaign ID.
        assertEq(staking.nextCampaignId(), expectedCampaignId + 1, "nextCampaignId");

        // It should set the correct campaign state.
        assertEq(staking.getAdmin(actualCampaignId), campaignCreator, "admin");
        assertEq(staking.getStakingToken(actualCampaignId), dai, "stakingToken");
        assertEq(staking.getStartTime(actualCampaignId), startTime, "startTime");
        assertEq(staking.getEndTime(actualCampaignId), endTime, "endTime");
        assertEq(staking.getRewardToken(actualCampaignId), rewardToken, "rewardToken");
        assertEq(staking.getTotalRewards(actualCampaignId), totalRewards, "totalRewards");
        assertEq(staking.wasCanceled(actualCampaignId), false, "wasCanceled");
    }
}
