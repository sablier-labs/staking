// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClaimableRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData =
            abi.encodeCall(stakingPool.claimableRewards, (campaignIds.nullCampaign, users.recipient));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        stakingPool.claimableRewards(campaignIds.canceledCampaign, users.recipient);
    }

    function test_RevertWhen_UserZeroAddress() external whenNotNull givenNotCanceled {
        vm.expectRevert(Errors.SablierStaking_UserZeroAddress.selector);
        stakingPool.claimableRewards(campaignIds.defaultCampaign, address(0));
    }

    function test_GivenStakedAmountZero() external view whenNotNull givenNotCanceled whenUserNotZeroAddress {
        uint128 actualRewards = stakingPool.claimableRewards(campaignIds.defaultCampaign, users.eve);
        assertEq(actualRewards, 0, "rewards");
    }

    function test_WhenClaimableRewardsZero()
        external
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        givenStakedAmountNotZero
    {
        warpStateTo(START_TIME);

        uint128 actualRewards = stakingPool.claimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, 0, "rewards");
    }

    function test_WhenCurrentTimeEqualsLastUpdateTime()
        external
        view
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        givenStakedAmountNotZero
        whenClaimableRewardsNotZero
    {
        uint128 actualRewards = stakingPool.claimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }

    function test_WhenCurrentTimeExceedsLastUpdateTime()
        external
        whenNotNull
        givenNotCanceled
        whenUserNotZeroAddress
        givenStakedAmountNotZero
        whenClaimableRewardsNotZero
    {
        // Warp the EVM state to 20% through the campaign.
        warpStateTo(WARP_20_PERCENT);

        // Warp the time to 40% through the campaign so that last time update is in the past.
        vm.warp(WARP_40_PERCENT);

        uint128 actualRewards = stakingPool.claimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
