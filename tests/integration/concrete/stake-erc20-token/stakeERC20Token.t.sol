// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { UserAccount } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract StakeERC20Token_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.stakeERC20Token, (poolIds.defaultPool, DEFAULT_AMOUNT));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.stakeERC20Token, (poolIds.nullPool, DEFAULT_AMOUNT));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_AmountZero() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StakingZeroAmount.selector, poolIds.defaultPool));
        sablierStaking.stakeERC20Token(poolIds.defaultPool, 0);
    }

    function test_RevertWhen_EndTimeInPast() external whenNoDelegateCall whenNotNull whenAmountNotZero {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInFuture.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_EndTimeInPresent() external whenNoDelegateCall whenNotNull whenAmountNotZero {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInFuture.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        whenAmountNotZero
        whenEndTimeInFuture
    {
        warpStateTo(START_TIME - 1);

        // It should stake tokens.
        _test_StakeERC20Token({ expectedRptScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        whenAmountNotZero
        whenEndTimeInFuture
    {
        warpStateTo(START_TIME);

        // It should stake tokens.
        _test_StakeERC20Token({ expectedRptScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPast() external whenNoDelegateCall whenNotNull whenAmountNotZero whenEndTimeInFuture {
        // It should stake tokens.
        _test_StakeERC20Token({
            expectedRptScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedUserRewards: REWARDS_EARNED_BY_RECIPIENT
        });
    }

    /// @dev Helper function to test the staking of ERC20 tokens.
    function _test_StakeERC20Token(uint256 expectedRptScaled, uint128 expectedUserRewards) private {
        UserAccount memory initialUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) + DEFAULT_AMOUNT;

        // It should emit {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, getBlockTimestamp(), expectedRptScaled, users.recipient, expectedUserRewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(users.recipient, address(sablierStaking), DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.StakeERC20Token(poolIds.defaultPool, users.recipient, DEFAULT_AMOUNT);

        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);

        // It should update user account.
        UserAccount memory actualUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        assertEq(
            actualUserAccount.directAmountStaked,
            initialUserAccount.directAmountStaked + DEFAULT_AMOUNT,
            "directAmountStakedByUser"
        );
        assertEq(actualUserAccount.snapshotRptEarnedScaled, expectedRptScaled, "rptEarnedScaled");
        assertEq(actualUserAccount.snapshotRewards, expectedUserRewards, "rewards");

        // It should increase total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualSnapshotTime, vars.actualRptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualSnapshotTime, getBlockTimestamp(), "globalSnapshotTime");
        assertEq(vars.actualRptScaled, expectedRptScaled, "snapshotRptDistributedScaled");
    }
}
