// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud, UD60x18, ZERO } from "@prb/math/src/UD60x18.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ClaimRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert since the fee does not meet the minimum fee.
    function testFuzz_RevertWhen_MinFeeNotPaid(uint256 fee) external whenNoDelegateCall whenNotNull {
        // Bound fee such that it does not meet the minimum fee.
        fee = bound(fee, 0, STAKING_MIN_FEE_WEI - 1);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, fee, STAKING_MIN_FEE_WEI)
        );
        sablierStaking.claimRewards{ value: fee }(poolIds.defaultPool, FEE_ON_REWARDS);
    }

    /// @dev It should revert.
    function testFuzz_RevertWhen_CallerNotStaker(
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
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
        sablierStaking.claimRewards{ value: STAKING_MIN_FEE_WEI }(poolIds.defaultPool, FEE_ON_REWARDS);
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
        UD60x18 feeOnRewards,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        givenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, STAKING_MIN_FEE_WEI, 1 ether);

        // Bound fee on rewards such that it is less than the maximum fee on rewards.
        feeOnRewards = bound(feeOnRewards, 0, MAX_FEE_ON_REWARDS);

        // Bound amount to stake such that there are always rewards to claim.
        amountToStake = boundUint128(amountToStake, 1e18, MAX_UINT128 - MAX_AMOUNT_STAKED);

        assumeNoExcludedCallers(caller);

        // Ensure caller is not a staker, recipient or comptroller for this test.
        vm.assume(caller != users.staker && caller != users.recipient && caller != address(comptroller));

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

        uint128 totalAmountStakedAtStake = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);

        // Randomly select a timestamp to claim rewards.
        uint40 claimTimestamp = randomUint40({
            min: stakingTimestamp + minDurationToEarnOneToken(amountToStake, totalAmountStakedAtStake),
            max: END_TIME + 1 days
        });

        // Warp to the new timestamp.
        vm.warp(claimTimestamp);

        // Test claim rewards.
        _test_ClaimRewards(caller, fee, feeOnRewards, claimTimestamp);
    }

    /// @dev It should run tests for existing stakers at multiple values for timestamp.
    function testFuzz_ClaimRewards(
        uint256 fee,
        UD60x18 feeOnRewards,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenMinFeePaid
        givenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, STAKING_MIN_FEE_WEI, 1 ether);

        // Bound fee on rewards such that it is less than the maximum fee on rewards.
        feeOnRewards = bound(feeOnRewards, 0, MAX_FEE_ON_REWARDS);

        // Change the caller.
        setMsgSender(users.recipient);

        // Bound timestamp between the start and 1 days after the end time.
        timestamp = boundUint40(timestamp, START_TIME + 1 seconds, END_TIME + 1 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Test claim rewards.
        _test_ClaimRewards(users.recipient, fee, feeOnRewards, timestamp);
    }

    function _test_ClaimRewards(address caller, uint256 fee, UD60x18 feeOnRewards, uint40 timestamp) private {
        uint256 initialComptrollerEthBalance = address(comptroller).balance;

        (uint256 expectedRewardsPerTokenScaled, uint128 expectedUserRewards) = calculateLatestRewards(caller);

        uint128 expectedRewardsTransferredToComptroller = ud(expectedUserRewards).mul(feeOnRewards).intoUint128();
        uint128 expectedRewardsTransferredToRecipient = expectedUserRewards - expectedRewardsTransferredToComptroller;

        // It should emit 1 {UpdateRewards}, 2 {Transfer} and 1 {ClaimRewards} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UpdateRewards(
            poolIds.defaultPool, timestamp, expectedRewardsPerTokenScaled, caller, expectedUserRewards
        );
        if (feeOnRewards > ZERO) {
            vm.expectEmit({ emitter: address(rewardToken) });
            emit IERC20.Transfer(address(sablierStaking), address(comptroller), expectedRewardsTransferredToComptroller);
        }
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), caller, expectedRewardsTransferredToRecipient);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClaimRewards(poolIds.defaultPool, caller, expectedRewardsTransferredToRecipient);

        // Claim the rewards.
        uint128 actualRewards = sablierStaking.claimRewards{ value: fee }(poolIds.defaultPool, feeOnRewards);

        // It should return the rewards.
        assertEq(actualRewards, expectedRewardsTransferredToRecipient, "return value");

        (uint256 actualRewardsPerTokenScaled,) = sablierStaking.userRewards(poolIds.defaultPool, caller);

        // It should set rewards to zero.
        assertEq(sablierStaking.claimableRewards(poolIds.defaultPool, caller), 0, "rewards");

        // It should set the rewards earned per token.
        assertEq(actualRewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");

        // It should transfer the min fee to comptroller.
        assertEq(address(comptroller).balance, initialComptrollerEthBalance + fee, "comptroller ETH balance");
    }
}
