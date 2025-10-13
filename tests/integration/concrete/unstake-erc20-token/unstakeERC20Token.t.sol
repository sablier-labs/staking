// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { UserAccount } from "src/types/DataTypes.sol";

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
        vars.expectedUserRewardsScaled = getScaledValue(REWARDS_EARNED_BY_RECIPIENT);

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            vars.expectedUserRewardsScaled
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(address(sablierStaking), users.recipient, DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeERC20Token(poolIds.defaultPool, users.recipient, DEFAULT_AMOUNT);

        // Unstake from the default pool.
        sablierStaking.unstakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);

        // It should update user account.
        UserAccount memory userAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        assertEq(userAccount.directAmountStaked, 0, "directAmountStakedByUser");
        assertEq(userAccount.snapshotRptEarnedScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rptEarnedScaled");
        assertEq(
            userAccount.claimableRewardsStoredScaled, vars.expectedUserRewardsScaled, "claimableRewardsStoredScaled"
        );

        // It should decrease total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualSnapshotTime, vars.actualRptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualSnapshotTime, WARP_40_PERCENT, "globalSnapshotTime");
        assertEq(vars.actualRptScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "snapshotRptDistributedScaled");
    }
}
