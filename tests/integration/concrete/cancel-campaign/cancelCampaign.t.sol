// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract CancelCampaign_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(staking.cancelCampaign, (defaultCampaignId));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(staking.cancelCampaign, (nullStreamId));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNoDelegateCall whenNotNull {
        // Cancel the campaign before the test.
        staking.cancelCampaign(defaultCampaignId);

        // It should revert.
        vm.expectRevert(Errors.SablierStaking_CampaignAlreadyCanceled.selector);
        staking.cancelCampaign(defaultCampaignId);
    }

    function test_RevertWhen_CallerNotCampaignAdmin() external whenNoDelegateCall whenNotNull givenNotCanceled {
        // Change the caller to Eve.
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotCampaignAdmin.selector, users.eve, users.campaignCreator
            )
        );
        staking.cancelCampaign(defaultCampaignId);
    }

    function test_RevertWhen_StartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        vm.warp(START_TIME + 1);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_CampaignAlreadyStarted.selector, START_TIME, START_TIME + 1)
        );
        staking.cancelCampaign(defaultCampaignId);
    }

    function test_RevertWhen_StartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        vm.warp(START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_CampaignAlreadyStarted.selector, START_TIME, START_TIME)
        );
        staking.cancelCampaign(defaultCampaignId);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenCallerCampaignAdmin
    {
        vm.warp(START_TIME - 1);

        // It should emit {Transfer} and {CancelCampaign} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(staking), users.campaignCreator, TOTAL_REWARDS_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.CancelCampaign(defaultCampaignId);

        // Cancel the campaign.
        uint256 expectedAmountRefunded = staking.cancelCampaign(defaultCampaignId);

        // It should cancel the campaign.
        assertEq(staking.wasCanceled(defaultCampaignId), true, "wasCanceled");

        // It should return the amount refunded.
        assertEq(expectedAmountRefunded, TOTAL_REWARDS_AMOUNT, "return value");
    }
}
