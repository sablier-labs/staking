// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract UnstakeERC20Token_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.unstakeERC20Token, (poolIds.defaultPool, DEFAULT_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.unstakeERC20Token, (poolIds.nullPool, DEFAULT_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_DirectStakedAmountZero() external whenNoDelegateCall whenNotNull {
        // Warp to pool start time when recipient has not direct staked amount.
        warpStateTo(START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_Overflow.selector, poolIds.defaultPool, DEFAULT_AMOUNT, 0)
        );
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
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
                Errors.SablierStaking_Overflow.selector,
                poolIds.defaultPool,
                amountToUnstake,
                DIRECT_AMOUNT_STAKED_BY_RECIPIENT
            )
        );
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, amountToUnstake);
    }

    function test_RevertWhen_AmountZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
    {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_UnstakingZeroAmount.selector, poolIds.defaultPool));
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, 0);
    }

    function test_WhenAmountNotZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenDirectStakedAmountNotZero
        whenAmountNotExceedDirectStakedAmount
        whenAmountNotZero
    {
        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) - DEFAULT_AMOUNT;

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(sablierStaking), users.recipient, DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeERC20Token(poolIds.defaultPool, users.recipient, DEFAULT_AMOUNT);

        // Unstake from the default pool.
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);

        // It should unstake.
        (, vars.actualDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualDirectAmountStaked, 0, "directAmountStakedByUser");

        // It should decrease total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualsnapshotTime, vars.actualRewardsPerTokenScaled) =
            sablierStaking.globalRptAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualsnapshotTime, WARP_40_PERCENT, "globalsnapshotTime");
        assertEq(vars.actualRewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "snapshotRptDistributedScaled");

        // It should update user rewards snapshot.
        (vars.actualRewardsPerTokenScaled, vars.actualUserRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualRewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rptEarnedScaled");
        assertEq(vars.actualUserRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
