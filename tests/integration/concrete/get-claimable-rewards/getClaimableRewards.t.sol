// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract GetClaimableRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(staking.getClaimableRewards, (campaignIds.nullCampaign, users.recipient));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.getClaimableRewards(campaignIds.canceledCampaign, users.recipient);
    }

    function test_RevertWhen_UserZeroAddress() external whenNotNull givenNotCanceled {
        vm.expectRevert(Errors.SablierStaking_ZeroAddress.selector);
        staking.getClaimableRewards(campaignIds.defaultCampaign, address(0));
    }

    function test_WhenClaimableRewardsZero() external view whenNotNull givenNotCanceled whenUserNotZeroAddress {
        uint128 actualRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, 0, "rewards");
    }

    function test_WhenCurrentTimeEqualsLastUpdateTime()
        external
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        whenClaimableRewardsNotZero
    {
        // Warp the EVM state to 40% through the campaign.
        warpStateTo(WARP_40_PERCENT);

        uint128 actualRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }

    function test_WhenCurrentTimeExceedsLastUpdateTime()
        external
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        whenClaimableRewardsNotZero
    {
        // Warp the EVM state to 20% through the campaign.
        warpStateTo(WARP_20_PERCENT);

        // Warp the time to 40% through the campaign.
        vm.warp(WARP_40_PERCENT);

        uint128 actualRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
