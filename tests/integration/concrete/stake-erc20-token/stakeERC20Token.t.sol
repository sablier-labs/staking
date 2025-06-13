// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Amounts } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract StakeERC20Token_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        setMsgSender(users.recipient);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(staking.stakeERC20Token, (campaignIds.defaultCampaign, DEFAULT_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(staking.stakeERC20Token, (campaignIds.nullCampaign, DEFAULT_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.stakeERC20Token(campaignIds.canceledCampaign, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_AmountZero() external whenNoDelegateCall whenNotNull givenNotCanceled {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StakingZeroAmount.selector, campaignIds.defaultCampaign)
        );
        staking.stakeERC20Token(campaignIds.defaultCampaign, 0);
    }

    function test_RevertWhen_EndTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
    {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignHasEnded.selector, campaignIds.defaultCampaign, END_TIME
            )
        );
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_EndTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
    {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignHasEnded.selector, campaignIds.defaultCampaign, END_TIME
            )
        );
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
        whenEndTimeInFuture
    {
        warpStateTo(START_TIME - 1);

        // It should stake tokens.
        _test_StakeERC20Token({ expectedRewardsPerTokenScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
        whenEndTimeInFuture
    {
        warpStateTo(START_TIME);

        // It should stake tokens.
        _test_StakeERC20Token({ expectedRewardsPerTokenScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
        whenEndTimeInFuture
    {
        // It should stake tokens.
        _test_StakeERC20Token({
            expectedRewardsPerTokenScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedUserRewards: REWARDS_EARNED_BY_RECIPIENT
        });
    }

    /// @dev Helper function to test the staking of ERC20 tokens.
    function _test_StakeERC20Token(uint256 expectedRewardsPerTokenScaled, uint128 expectedUserRewards) private {
        Amounts memory amountStakedByUser = staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        uint128 expectedAmountStakedByUser = amountStakedByUser.totalAmountStaked + DEFAULT_AMOUNT;
        uint128 expectedDirectAmountStakedByUser = amountStakedByUser.directAmountStaked + DEFAULT_AMOUNT;

        // It should emit {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            getBlockTimestamp(),
            expectedRewardsPerTokenScaled,
            users.recipient,
            expectedUserRewards,
            amountStakedByUser.totalAmountStaked
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(users.recipient, address(staking), DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.StakeERC20Token(campaignIds.defaultCampaign, users.recipient, DEFAULT_AMOUNT);

        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);

        // It should stake tokens.
        amountStakedByUser = staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        assertEq(amountStakedByUser.totalAmountStaked, expectedAmountStakedByUser, "totalAmountStakedByUser");
        assertEq(amountStakedByUser.directAmountStaked, expectedDirectAmountStakedByUser, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(globalLastUpdateTime, getBlockTimestamp(), "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(userLastUpdateTime, getBlockTimestamp(), "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, expectedUserRewards, "rewards");
    }
}
