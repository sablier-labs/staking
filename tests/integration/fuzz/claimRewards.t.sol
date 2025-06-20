// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ClaimRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert since the fee does not meet the minimum fee.
    function testFuzz_RevertWhen_FeeNotPaid(uint256 fee) external whenNoDelegateCall whenNotNull givenNotCanceled {
        // Bound fee such that it does not meet the minimum fee.
        fee = bound(fee, 0, FEE - 1);

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_InsufficientFeePayment.selector, fee, FEE));
        staking.claimRewards{ value: fee }(campaignIds.defaultCampaign);
    }

    /// @dev It should revert since the campaign has not started yet.
    function testFuzz_RevertWhen_StartTimeInFuture(uint40 timestamp)
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenFeePaid
    {
        // Bound timestamp such that the start time is in the future.
        timestamp = boundUint40(timestamp, 0, START_TIME - 1);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignNotStarted.selector, campaignIds.defaultCampaign, START_TIME
            )
        );
        staking.claimRewards{ value: FEE }(campaignIds.defaultCampaign);
    }

    /// @dev It should revert.
    function testFuzz_RevertWhen_CallerNotStaker(
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
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
            abi.encodeWithSelector(
                Errors.SablierStaking_ZeroClaimableRewards.selector, campaignIds.defaultCampaign, caller
            )
        );
        staking.claimRewards{ value: FEE }(campaignIds.defaultCampaign);
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
        givenNotCanceled
        whenFeePaid
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, FEE, 1 ether);

        // Bound amount to stake such that there are always rewards to claim.
        amountToStake = boundUint128(amountToStake, 1e18, MAX_UINT128 - MAX_AMOUNT_STAKED);

        assumeNoExcludedCallers(caller);

        // Ensure caller is neither a staker nor a recipient for this test.
        vm.assume(caller != users.staker && caller != users.recipient);

        // Bound timestamp between the start and 40% through the campaign.
        uint40 stakingTimestamp = boundUint40(timestamp, START_TIME + 1 seconds, WARP_40_PERCENT);

        // Warp EVM state to the given timestamp.
        warpStateTo(stakingTimestamp);

        // Change the caller and approve the staking contract.
        setMsgSender(caller);
        deal({ token: address(stakingToken), to: caller, give: amountToStake });
        stakingToken.approve(address(staking), amountToStake);

        // Caller stakes first and then warp to a new randomized timestamp.
        staking.stakeERC20Token(campaignIds.defaultCampaign, amountToStake);

        uint128 totalAmountStakedAtStake = staking.totalAmountStaked(campaignIds.defaultCampaign);

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
        givenNotCanceled
        whenFeePaid
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Bound fee such that it meets the minimum fee.
        fee = bound(fee, FEE, 1 ether);

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
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign, timestamp, expectedRewardsPerTokenScaled, caller, expectedUserRewards
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(staking), caller, expectedUserRewards);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.ClaimRewards(campaignIds.defaultCampaign, caller, expectedUserRewards);

        // Claim the rewards.
        uint128 actualRewards = staking.claimRewards{ value: fee }(campaignIds.defaultCampaign);

        // It should return the rewards.
        assertEq(actualRewards, expectedUserRewards, "return value");

        (uint40 actualLastUpdateTime, uint256 actualRewardsPerTokenScaled,) =
            staking.userSnapshot(campaignIds.defaultCampaign, caller);

        // It should set last time update to current timestamp.
        assertEq(actualLastUpdateTime, timestamp, "lastUpdateTime");

        // It should set rewards to zero.
        assertEq(staking.getClaimableRewards(campaignIds.defaultCampaign, caller), 0, "rewards");

        // It should set the rewards earned per token.
        assertEq(actualRewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");

        // It should deposit fee into the staking contract.
        assertEq(address(staking).balance, fee, "staking contract balance");
    }
}
