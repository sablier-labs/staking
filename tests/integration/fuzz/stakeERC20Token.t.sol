// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract StakeERC20Token_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Different callers with different amounts staked.
    /// - Multiple values for the block timestamp from pool create time until the end time.
    function testFuzz_StakeERC20Token(
        uint128 amount,
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
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
        stakingToken.approve(address(sablierStaking), amount);

        (vars.expectedRewardsPerTokenScaled, vars.expectedUserRewards) = calculateLatestRewards(caller);
        (,, uint128 initialDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, caller);

        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) + amount;

        // It should emit {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, timestamp, vars.expectedRewardsPerTokenScaled, caller, vars.expectedUserRewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(caller, address(sablierStaking), amount);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.StakeERC20Token(poolIds.defaultPool, caller, amount);

        // Stake ERC20 tokens into the default pool.
        sablierStaking.stakeERC20Token(poolIds.defaultPool, amount);

        // It should stake tokens.
        (,, vars.actualDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, caller);
        assertEq(vars.actualDirectAmountStaked, initialDirectAmountStaked + amount, "directAmountStakedByUser");

        // It should increase total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualLastUpdateTime, vars.actualRewardsPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(vars.actualLastUpdateTime, timestamp, "globalLastUpdateTime");
        assertEq(
            vars.actualRewardsPerTokenScaled, vars.expectedRewardsPerTokenScaled, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (vars.actualLastUpdateTime, vars.actualRewardsPerTokenScaled, vars.actualUserRewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, caller);
        assertEq(vars.actualLastUpdateTime, timestamp, "userLastUpdateTime");
        assertEq(vars.actualRewardsPerTokenScaled, vars.expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(vars.actualUserRewards, vars.expectedUserRewards, "rewards");
    }
}
