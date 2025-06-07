// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClaimRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        setMsgSender(users.recipient);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(staking.claimRewards, (campaignIds.defaultCampaign));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(staking.claimRewards, (campaignIds.nullCampaign));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.claimRewards(campaignIds.canceledCampaign);
    }

    function test_RevertWhen_StartTimeInFuture() external whenNoDelegateCall whenNotNull givenNotCanceled {
        warpStateTo(START_TIME - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignNotStarted.selector, campaignIds.defaultCampaign, START_TIME
            )
        );
        staking.claimRewards(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_StartTimeInPresent() external whenNoDelegateCall whenNotNull givenNotCanceled {
        warpStateTo(START_TIME);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_ZeroClaimableRewards.selector, campaignIds.defaultCampaign, users.recipient
            )
        );
        staking.claimRewards(campaignIds.defaultCampaign);
    }

    function test_RevertWhen_ClaimableRewardsZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenStartTimeInPast
    {
        // Switch to a different user who has no rewards.
        setMsgSender(users.eve);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_ZeroClaimableRewards.selector, campaignIds.defaultCampaign, users.eve
            )
        );
        staking.claimRewards(campaignIds.defaultCampaign);
    }

    function test_WhenClaimableRewardsNotZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenStartTimeInPast
    {
        uint256 initialCallerBalance = rewardToken.balanceOf(users.recipient);
        uint256 initialContractBalance = rewardToken.balanceOf(address(staking));

        // It should emit {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            WARP_40_PERCENT,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN),
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT,
            AMOUNT_STAKED_BY_RECIPIENT
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(staking), users.recipient, REWARDS_EARNED_BY_RECIPIENT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.ClaimRewards(campaignIds.defaultCampaign, users.recipient, REWARDS_EARNED_BY_RECIPIENT);

        // Claim the rewards.
        uint128 actualRewards = staking.claimRewards(campaignIds.defaultCampaign);

        (uint40 lastUpdateTime, uint256 rewardsEarnedPerTokenScaled,) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        // It should set rewards to zero.
        assertEq(staking.getClaimableRewards(campaignIds.defaultCampaign, users.recipient), 0, "rewards");

        // It should set last time update to current timestamp.
        assertEq(lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");

        // It should transfer the rewards to the caller.
        assertEq(
            rewardToken.balanceOf(users.recipient),
            initialCallerBalance + REWARDS_EARNED_BY_RECIPIENT,
            "recipient balance"
        );
        assertEq(
            rewardToken.balanceOf(address(staking)),
            initialContractBalance - REWARDS_EARNED_BY_RECIPIENT,
            "contract balance"
        );

        // It should return the rewards.
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "return value");

        // It should update the user snapshot correctly.
        assertEq(
            rewardsEarnedPerTokenScaled, getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN), "rewardsEarnedPerTokenScaled"
        );
    }
}
