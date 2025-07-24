// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ClaimRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert since the fee does not meet the minimum fee.
    function testFuzz_RevertWhen_FeeNotPaid(uint256 fee) external whenNoDelegateCall whenNotNull {
        // Bound fee such that it does not meet the minimum fee.
        fee = bound(fee, 0, STAKING_MIN_FEE_WEI - 1);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, fee, STAKING_MIN_FEE_WEI)
        );
        sablierStaking.claimRewards{ value: fee }(poolIds.defaultPool);
    }

    /// @dev It should revert since the start time is in the future.
    function testFuzz_RevertWhen_StartTimeInFuture(uint40 timestamp)
        external
        whenNoDelegateCall
        whenNotNull
        whenFeePaid
    {
        // Bound timestamp such that the start time is in the future.
        timestamp = boundUint40(timestamp, 0, START_TIME - 1);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StartTimeInFuture.selector, poolIds.defaultPool, START_TIME)
        );
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool);
    }

    /// @dev It should revert.
    function testFuzz_RevertWhen_CallerNotStaker(
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenFeePaid
        whenStartTimeInPast
    {
        // Make sure caller is not a staker.
        vm.assume(caller != users.staker && caller != users.recipient);

        // Bound timestamp between the start and 365 days after the end time.
        timestamp = boundUint40(timestamp, START_TIME + 1, END_TIME + 365 days);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Change the caller.
        setMsgSender(caller);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_ZeroClaimableRewards.selector, poolIds.defaultPool, caller)
        );
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool);
    }

    /// @dev It should run tests for a multiple callers when caller is staking for the first time.
    ///  - Warp to a new timestamp.
    ///  - Caller stakes some amount.
    ///  - Warp to a new timestamp.
    ///  - Caller claims rewards.
    function testFuzz_ClaimRewards_WhenNewCallerStakes(
        uint128 amountToStake,
        address caller,
        uint256 fee,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenFeePaid
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, STAKING_MIN_FEE_WEI, 1 ether);

        // Bound amount to stake such that there are always rewards to claim.
        amountToStake = boundUint128(amountToStake, 1e18, MAX_UINT128 - MAX_AMOUNT_STAKED);

        assumeNoExcludedCallers(caller);

        // Ensure caller is neither a staker nor a recipient for this test.
        vm.assume(caller != users.staker && caller != users.recipient);

        // Bound timestamp between the start and 40% through the rewards period.
        uint40 stakingTimestamp = boundUint40(timestamp, START_TIME + 1 seconds, WARP_40_PERCENT);

        // Warp EVM state to the given timestamp.
        warpStateTo(stakingTimestamp);

        // Change the caller and approve the staking pool.
        setMsgSender(caller);
        deal({ token: address(stakingToken), to: caller, give: amountToStake });
        stakingToken.approve(address(sablierStaking), amountToStake);

        // Caller stakes first and then warp to a new randomized timestamp.
        sablierStaking.stakeERC20Token(poolIds.defaultPool, amountToStake);

        uint128 totalAmountStakedAtStake = sablierStaking.totalAmountStaked(poolIds.defaultPool);

        // Randomly select a timestamp to claim rewards.
        uint40 claimTimestamp = randomUint40({
            min: stakingTimestamp + minDurationToEarnOneToken(amountToStake, totalAmountStakedAtStake),
            max: END_TIME + 1 days
        });

        // Warp to the new timestamp.
        vm.warp(claimTimestamp);

        // Test claim rewards.
        _test_ClaimRewards(caller, fee, claimTimestamp);
    }

    /// @dev It should run tests for existing stakers at multiple values for timestamp.
    function testFuzz_ClaimRewards(
        uint256 fee,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenFeePaid
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, STAKING_MIN_FEE_WEI, 1 ether);

        // Change the caller.
        setMsgSender(users.recipient);

        // Bound timestamp between the start and 1 days after the end time.
        timestamp = boundUint40(timestamp, START_TIME + 1 seconds, END_TIME + 1 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Test claim rewards.
        _test_ClaimRewards(users.recipient, fee, timestamp);
    }

    function _test_ClaimRewards(address caller, uint256 fee, uint40 timestamp) private {
        (uint256 expectedRewardsPerTokenScaled, uint128 expectedUserRewards) = calculateLatestRewards(caller);

        // It should emit {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, timestamp, expectedRewardsPerTokenScaled, caller, expectedUserRewards
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), caller, expectedUserRewards);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClaimRewards(poolIds.defaultPool, caller, expectedUserRewards);

        // Claim the rewards.
        uint128 actualRewards = sablierStaking.claimRewards{ value: fee }(poolIds.defaultPool);

        // It should return the rewards.
        assertEq(actualRewards, expectedUserRewards, "return value");

        (uint40 actualLastUpdateTime, uint256 actualRewardsPerTokenScaled,) =
            sablierStaking.userSnapshot(poolIds.defaultPool, caller);

        // It should set last time update to current timestamp.
        assertEq(actualLastUpdateTime, timestamp, "lastUpdateTime");

        // It should set rewards to zero.
        assertEq(sablierStaking.claimableRewards(poolIds.defaultPool, caller), 0, "rewards");

        // It should set the rewards earned per token.
        assertEq(actualRewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");

        // It should deposit fee into the staking pool.
        assertEq(address(sablierStaking).balance, fee, "staking pool balance");
    }
}
