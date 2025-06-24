// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract CancelCampaign_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        // Set campaign creator as the default caller for this test.
        setMsgSender(users.campaignCreator);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(staking.cancelCampaign, (campaignIds.defaultCampaign));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(staking.cancelCampaign, (campaignIds.nullCampaign));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.cancelCampaign(campaignIds.canceledCampaign);
    }

    function test_RevertWhen_CallerNotCampaignAdmin() external whenNoDelegateCall whenNotNull givenNotCanceled {
        // Change the caller to Eve.
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotCampaignAdmin.selector,
                campaignIds.defaultCampaign,
                users.eve,
                users.campaignCreator
            )
        );
        staking.cancelCampaign(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_StartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignAlreadyStarted.selector, campaignIds.defaultCampaign, START_TIME
            )
        );
        staking.cancelCampaign(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_StartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        warpStateTo(START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignAlreadyStarted.selector, campaignIds.defaultCampaign, START_TIME
            )
        );
        staking.cancelCampaign(campaignIds.defaultCampaign);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        warpStateTo(START_TIME - 1);

        // It should emit {Transfer} and {CancelCampaign} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(staking), users.campaignCreator, REWARD_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.CancelCampaign(campaignIds.defaultCampaign);

        // Cancel the campaign.
        uint256 expectedAmountRefunded = staking.cancelCampaign(campaignIds.defaultCampaign);

        // It should cancel the campaign.
        assertEq(staking.wasCanceled(campaignIds.defaultCampaign), true, "wasCanceled");

        // It should return the amount refunded.
        assertEq(expectedAmountRefunded, REWARD_AMOUNT, "return value");
    }
}
