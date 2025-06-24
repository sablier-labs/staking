// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract UnstakeERC20Token_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert because caller has no direct amount staked.
    function testFuzz_RevertGiven_DirectStakedAmountZero(
        address caller,
        uint128 amount,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
    {
        assumeNoExcludedCallers(caller);

        // For this test, we will use a new caller.
        vm.assume(caller != users.recipient && caller != users.staker);

        // Bound timestamp so that it is greater than the campaign create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 365 days);

        // Bound amount such that it does not exceed total staked amount.
        amount = boundUint128(amount, 1, STREAM_AMOUNT_18D);

        // Stake into the campaign using a Lockup NFT.
        uint256 streamId = defaultCreateWithDurationsLL(caller);
        setMsgSender(caller);
        lockup.setApprovalForAll({ operator: address(staking), approved: true });
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamId);

        // Check that caller has total staked amount.
        uint128 totalAmountStaked = staking.totalAmountStakedByUser(campaignIds.defaultCampaign, caller);
        assertEq(totalAmountStaked, STREAM_AMOUNT_18D, "totalAmountStaked");

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_AmountExceedsStakedAmount.selector, campaignIds.defaultCampaign, amount, 0
            )
        );

        // Try to unstake ERC20 tokens from the campaign.
        staking.unstakeERC20Token(campaignIds.defaultCampaign, amount);
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Unstaking from a canceled campaign.
    /// - Different non-zero values for the amount.
    /// - Multiple values for the block timestamp from campaign create time.
    function testFuzz_UnstakeERC20Token_GivenCanceled(
        uint128 amount,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
        whenAmountNotZero
    {
        // Bound timestamp so that it is greater than the campaign create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 365 days);

        // Warp amount so that it does not exceed direct staked amount.
        amount = boundUint128(amount, 1, DEFAULT_AMOUNT);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        setMsgSender(users.staker);

        // It should emit {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(staking), users.staker, amount);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.UnstakeERC20Token(campaignIds.canceledCampaign, users.staker, amount);

        // Unstake from the canceled campaign.
        staking.unstakeERC20Token(campaignIds.canceledCampaign, amount);

        // It should unstake.
        (,, uint128 directAmountStaked) = staking.userShares(campaignIds.canceledCampaign, users.staker);
        assertEq(directAmountStaked, DEFAULT_AMOUNT - amount, "directAmountStakedByUser");
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Unstaking from a default campaign.
    /// - Different non-zero values for the amount.
    /// - Multiple values for the block timestamp from campaign create time.
    /// - Caller either recipient or staker.
    function testFuzz_UnstakeERC20Token(
        uint256 callerSeed,
        uint128 amount,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
        whenAmountNotZero
    {
        // Pick a caller based on the seed.
        address caller = callerSeed % 2 == 0 ? users.recipient : users.staker;

        // Bound timestamp so that it is greater than the campaign create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 365 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // If direct amount staked is 0, forward time to 20% through the campaign.
        (,, uint128 previousDirectAmountStaked) = staking.userShares(campaignIds.defaultCampaign, caller);
        if (previousDirectAmountStaked == 0) {
            timestamp = boundUint40(timestamp, WARP_20_PERCENT, END_TIME + 365 days);
            warpStateTo(timestamp);
            (,, previousDirectAmountStaked) = staking.userShares(campaignIds.defaultCampaign, caller);
        }

        // Warp amount so that it does not exceed direct staked amount.
        amount = boundUint128(amount, 1, previousDirectAmountStaked);

        setMsgSender(caller);

        (uint256 rewardsEarnedPerTokenScaled, uint128 rewards) = calculateLatestRewards(caller);

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign, timestamp, rewardsEarnedPerTokenScaled, caller, rewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(staking), caller, amount);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.UnstakeERC20Token(campaignIds.defaultCampaign, caller, amount);

        // Unstake from the default campaign.
        staking.unstakeERC20Token(campaignIds.defaultCampaign, amount);

        // It should unstake.
        (,, uint128 actualDirectAmountStaked) = staking.userShares(campaignIds.defaultCampaign, caller);
        assertEq(actualDirectAmountStaked, previousDirectAmountStaked - amount, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 actualLastUpdateTime, uint256 actualRewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(actualLastUpdateTime, timestamp, "globalLastUpdateTime");
        assertEq(
            actualRewardsDistributedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (actualLastUpdateTime, rewardsEarnedPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, caller);
        assertEq(actualLastUpdateTime, timestamp, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
