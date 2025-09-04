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

        // Bound timestamp so that it is greater than the pool create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 365 days);

        // Bound amount such that it does not exceed total staked amount.
        amount = boundUint128(amount, 1, STREAM_AMOUNT_18D);

        // Stake into the pool using a Lockup NFT.
        uint256 streamId = defaultCreateWithDurationsLL(caller);
        setMsgSender(caller);
        lockup.setApprovalForAll({ operator: address(sablierStaking), approved: true });
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamId);

        // Check that caller has total staked amount.
        vars.actualTotalAmountStaked = sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, caller);
        assertEq(vars.actualTotalAmountStaked, STREAM_AMOUNT_18D, "totalStakedAmount");

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_Overflow.selector, poolIds.defaultPool, amount, 0));

        // Try to unstake ERC20 tokens from the pool.
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, amount);
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Unstaking from a default pool.
    /// - Different non-zero values for the amount.
    /// - Multiple values for the block timestamp from pool create time.
    /// - Caller either recipient or staker.
    function testFuzz_UnstakeERC20Token(
        uint256 callerSeed,
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
        // Pick a caller based on the seed.
        address caller = callerSeed % 2 == 0 ? users.recipient : users.staker;

        // Bound timestamp so that it is greater than the pool create time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME + 365 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // If direct amount staked is 0, forward time to 20% through the rewards period.
        (, uint128 previousDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, caller);
        if (previousDirectAmountStaked == 0) {
            timestamp = boundUint40(timestamp, WARP_20_PERCENT, END_TIME + 365 days);
            warpStateTo(timestamp);
            (, previousDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, caller);
        }

        // Warp amount so that it does not exceed direct staked amount.
        amount = boundUint128(amount, 1, previousDirectAmountStaked);

        setMsgSender(caller);

        (vars.expectedRptScaled, vars.expectedUserRewards) = calculateLatestRewards(caller);

        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) - amount;

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, timestamp, vars.expectedRptScaled, caller, vars.expectedUserRewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(sablierStaking), caller, amount);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeERC20Token(poolIds.defaultPool, caller, amount);

        // Unstake from the default pool.
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, amount);

        // It should unstake.
        (, vars.actualDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, caller);
        assertEq(vars.actualDirectAmountStaked, previousDirectAmountStaked - amount, "directAmountStakedByUser");

        // It should decrease total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualsnapshotTime, vars.actualRptScaled) = sablierStaking.globalRptAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualsnapshotTime, timestamp, "globalsnapshotTime");
        assertEq(vars.actualRptScaled, vars.expectedRptScaled, "snapshotRptDistributedScaled");

        // It should update user rewards snapshot.
        (vars.actualRptScaled, vars.actualUserRewards) = sablierStaking.userRewards(poolIds.defaultPool, caller);
        assertEq(vars.actualRptScaled, vars.expectedRptScaled, "rptEarnedScaled");
        assertEq(vars.actualUserRewards, vars.expectedUserRewards, "rewards");
    }
}
