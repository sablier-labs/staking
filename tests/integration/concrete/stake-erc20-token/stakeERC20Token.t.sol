// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

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

    function test_RevertGiven_Closed() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.stakeERC20Token(poolIds.closedPool, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_AmountZero() external whenNoDelegateCall whenNotNull givenNotClosed {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StakingZeroAmount.selector, poolIds.defaultPool));
        sablierStaking.stakeERC20Token(poolIds.defaultPool, 0);
    }

    function test_RevertWhen_EndTimeInPast() external whenNoDelegateCall whenNotNull givenNotClosed whenAmountNotZero {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInFuture.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
    }

    function test_RevertWhen_EndTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotClosed
        whenAmountNotZero
    {
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
        givenNotClosed
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
        givenNotClosed
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
        givenNotClosed
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
        (,, uint128 initialDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);

        // It should emit {SnapshotRewards}, {Transfer} and {StakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            getBlockTimestamp(),
            expectedRewardsPerTokenScaled,
            users.recipient,
            expectedUserRewards
        );
        vm.expectEmit({ emitter: address(stakingToken) });
        emit IERC20.Transfer(users.recipient, address(sablierStaking), DEFAULT_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.StakeERC20Token(poolIds.defaultPool, users.recipient, DEFAULT_AMOUNT);

        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);

        // It should stake tokens.
        (,, uint128 actualDirectAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(actualDirectAmountStaked, initialDirectAmountStaked + DEFAULT_AMOUNT, "directAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(globalLastUpdateTime, getBlockTimestamp(), "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);
        assertEq(userLastUpdateTime, getBlockTimestamp(), "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, expectedUserRewards, "rewards");
    }
}
