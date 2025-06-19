// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract UnstakeERC20Token_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(staking.unstakeERC20Token, (campaignIds.defaultCampaign, DEFAULT_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(staking.unstakeERC20Token, (campaignIds.nullCampaign, DEFAULT_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_DirectStakedAmountZero() external whenNoDelegateCall whenNotNull {
        // Warp to campaign start time when recipient has not direct staked amount.
        warpStateTo(START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_AmountExceedsStakedAmount.selector, campaignIds.defaultCampaign, DEFAULT_AMOUNT, 0
            )
        );
        staking.unstakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_AmountExceedsDirectStakedAmount()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
    {
        uint128 amountToUnstake = DIRECT_AMOUNT_STAKED_BY_RECIPIENT + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_AmountExceedsStakedAmount.selector,
                campaignIds.defaultCampaign,
                amountToUnstake,
                DIRECT_AMOUNT_STAKED_BY_RECIPIENT
            )
        );
        staking.unstakeERC20Token(campaignIds.defaultCampaign, amountToUnstake);
    }

    function test_RevertWhen_AmountZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
    {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_UnstakingZeroAmount.selector, campaignIds.defaultCampaign)
        );
        staking.unstakeERC20Token(campaignIds.defaultCampaign, 0);
    }

    function test_GivenCanceled()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
        whenAmountNotZero
    {
        // For this test, we use the users.staker because he has staked amount in the canceled campaign.
        setMsgSender(users.staker);

        // It should emit {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(staking), users.staker, DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.UnstakeERC20Token(campaignIds.canceledCampaign, users.staker, DEFAULT_AMOUNT);

        // Unstake from the canceled campaign.
        staking.unstakeERC20Token(campaignIds.canceledCampaign, DEFAULT_AMOUNT);

        // It should unstake.
        (,, uint128 actualDirectAmountStaked) = staking.userShares(campaignIds.canceledCampaign, users.staker);
        assertEq(actualDirectAmountStaked, 0, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.canceledCampaign);
        assertEq(globalLastUpdateTime, WARP_40_PERCENT, "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, 0, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.canceledCampaign, users.staker);
        assertEq(userLastUpdateTime, WARP_40_PERCENT, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, 0, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, 0, "rewards");
    }

    function test_GivenNotCanceled()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
        whenAmountNotZero
    {
        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(staking), users.recipient, DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.UnstakeERC20Token(campaignIds.defaultCampaign, users.recipient, DEFAULT_AMOUNT);

        // Unstake from the default campaign.
        staking.unstakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);

        // It should unstake.
        (,, uint128 actualDirectAmountStaked) = staking.userShares(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualDirectAmountStaked, 0, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(globalLastUpdateTime, WARP_40_PERCENT, "globalLastUpdateTime");
        assertEq(
            rewardsDistributedPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(userLastUpdateTime, WARP_40_PERCENT, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
