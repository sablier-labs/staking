// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract StakeERC20Token_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Different callers with different amounts staked.
    /// - Multiple values for the block timestamp from campaign create time until the end time.
    function testFuzz_StakeERC20Token(
        uint128 amount,
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenAmountNotZero
        whenEndTimeInFuture
    {
        assumeNoExcludedCallers(caller);

        // Bound amount such that it does not overflow uint128.
        amount = boundUint128(amount, 1e18, MAX_UINT128 - MAX_AMOUNT_STAKED);

        // Bound timestamp so that it is less than the end time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME - 1);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Change caller and deal tokens.
        setMsgSender(caller);
        deal({ token: address(stakingToken), to: caller, give: amount });
        stakingToken.approve(address(stakingPool), amount);

        (uint256 expectedRewardsPerTokenScaled, uint128 expectedUserRewards) = calculateLatestRewards(caller);
        (,, uint128 initialDirectAmountStaked) = stakingPool.userShares(campaignIds.defaultCampaign, caller);

        // It should emit {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
        vm.expectEmit({ emitter: address(stakingPool) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign, timestamp, expectedRewardsPerTokenScaled, caller, expectedUserRewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(caller, address(stakingPool), amount);
        vm.expectEmit({ emitter: address(stakingPool) });
        emit ISablierStaking.StakeERC20Token(campaignIds.defaultCampaign, caller, amount);

        // Stake ERC20 tokens into the default campaign.
        stakingPool.stakeERC20Token(campaignIds.defaultCampaign, amount);

        // It should stake tokens.
        (,, uint128 actualDirectAmountStaked) = stakingPool.userShares(campaignIds.defaultCampaign, caller);
        assertEq(actualDirectAmountStaked, initialDirectAmountStaked + amount, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 actualGlobalLastUpdateTime, uint256 actualRewardsDistributedPerTokenScaled) =
            stakingPool.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(actualGlobalLastUpdateTime, timestamp, "globalLastUpdateTime");
        assertEq(
            actualRewardsDistributedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (uint40 actualUserLastUpdateTime, uint256 actualRewardsEarnedPerTokenScaled, uint128 actualRewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, caller);
        assertEq(actualUserLastUpdateTime, timestamp, "userLastUpdateTime");
        assertEq(actualRewardsEarnedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(actualRewards, expectedUserRewards, "rewards");
    }
}
