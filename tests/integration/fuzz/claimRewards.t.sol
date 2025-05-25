// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Amounts } from "src/types/DataTypes.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract ClaimRewards_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert since the campaign has not started yet.
    function testFuzz_RevertWhen_StartTimeInFuture(uint40 timestamp)
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
    {
        // Bound timestamp such that the start time is in the future.
        timestamp = boundUint40(timestamp, 0, START_TIME - 1);

        // Warp to the EVM state at the given timestamp.
        warpStateTo(timestamp);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignNotStarted.selector, campaignIds.defaultCampaign, START_TIME
            )
        );
        staking.claimRewards(campaignIds.defaultCampaign);
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
        whenStartTimeInPast
    {
        // Make sure caller is not a staker.
        vm.assume(caller != users.staker && caller != users.recipient);

        // Bound timestamp between the start and 365 days after the end time.
        timestamp = boundUint40(timestamp, START_TIME + 1, END_TIME + 365 days);

        // Warp to the EVM state at the given timestamp.
        warpStateTo(timestamp);

        // Change the caller.
        setMsgSender(caller);

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_ZeroClaimableRewards.selector, campaignIds.defaultCampaign, caller
            )
        );
        staking.claimRewards(campaignIds.defaultCampaign);
    }

    /// @dev It should run tests for a multiple callers when caller is staking for the first time.
    ///  - Warp to a new timestamp.
    ///  - Caller stakes some amount.
    ///  - Warp to a new timestamp.
    ///  - Caller claims rewards.
    function testFuzz_ClaimRewards_WhenNewCallerStakes(
        uint128 amountToStake,
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Bound amount to stake such that there are always rewards to claim.
        amountToStake = boundUint128(amountToStake, 1e18, MAX_UINT128 / 2);

        assumeNoExcludedCallers(caller);

        // Ensure caller is neither a staker nor a recipient for this test.
        vm.assume(caller != users.staker && caller != users.recipient);

        // Bound timestamp between the start and 40% through the campaign.
        uint40 stakingTimestamp = boundUint40(timestamp, START_TIME + 1 seconds, WARP_40_PERCENT);

        // Warp EVM state to the given timestamp.
        warpStateTo(stakingTimestamp);

        // Change the caller and approve the staking contract.
        setMsgSender(caller);
        deal({ token: address(dai), to: caller, give: amountToStake });
        dai.approve(address(staking), amountToStake);

        // Caller stakes first and then warp to a new randomized timestamp.
        staking.stakeERC20Token(campaignIds.defaultCampaign, amountToStake);

        // Get total staked amount.
        (, uint256 rewardsPerTokenScaledAtStake) = staking.globalSnapshot(campaignIds.defaultCampaign);
        uint128 totalStakedAmountAtStake = staking.totalStakedTokens(campaignIds.defaultCampaign);

        // Randomly select a timestamp to claim rewards.
        uint40 claimTimestamp = randomUint40({
            min: stakingTimestamp + minDurationToEarnOneToken(amountToStake, totalStakedAmountAtStake),
            max: END_TIME + 1 days
        });

        // Calculate reward duration for caller.
        uint40 rewardDurationSinceStake =
            claimTimestamp >= END_TIME ? END_TIME - stakingTimestamp : claimTimestamp - stakingTimestamp;

        // Calculate expected rewards.
        uint128 expectedRewardsDistributedSinceStake = REWARD_AMOUNT * rewardDurationSinceStake / CAMPAIGN_DURATION;

        uint256 expectedRewardsPerTokenScaledSinceStake =
            getScaledValue(expectedRewardsDistributedSinceStake) / totalStakedAmountAtStake;
        vars.expectedUserRewards = getDescaledValue(expectedRewardsPerTokenScaledSinceStake * amountToStake);
        vars.expectedRewardsPerTokenScaled = rewardsPerTokenScaledAtStake + expectedRewardsPerTokenScaledSinceStake;

        // Warp to the new timestamp.
        vm.warp(claimTimestamp);

        // Test claim rewards.
        _test_ClaimRewards(caller, claimTimestamp);
    }

    /// @dev It should run tests for existing stakers at multiple values for timestamp.
    function testFuzz_ClaimRewards(uint40 timestamp)
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenStartTimeInPast
        whenClaimableRewardsNotZero
    {
        // Change the caller.
        setMsgSender(users.recipient);

        // Bound timestamp between the start and 1 days after the end time.
        timestamp = boundUint40(timestamp, START_TIME + 1 seconds, END_TIME + 1 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        uint128 totalStakedAmount = staking.totalStakedTokens(campaignIds.defaultCampaign);
        (uint40 lastTimeUpdate, uint256 globalRewardsPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);

        // Calculate time elapsed since last global snapshot.
        uint40 timeElapsed = timestamp >= END_TIME ? END_TIME - lastTimeUpdate : timestamp - lastTimeUpdate;

        // Calculate expected rewards.
        uint128 rewardsSinceLastUpdate = REWARD_AMOUNT * timeElapsed / CAMPAIGN_DURATION;

        vars.expectedRewardsPerTokenScaled =
            globalRewardsPerTokenScaled + getScaledValue(rewardsSinceLastUpdate) / totalStakedAmount;

        (, uint256 userRewardsPerTokenScaled, uint128 rewardsAtLastUserSnapshot) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        Amounts memory amounts = staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);

        vars.expectedUserRewards = rewardsAtLastUserSnapshot
            + getDescaledValue((vars.expectedRewardsPerTokenScaled - userRewardsPerTokenScaled) * amounts.totalStakedAmount);

        // Test claim rewards.
        _test_ClaimRewards(users.recipient, timestamp);
    }

    function _test_ClaimRewards(address caller, uint40 timestamp) private {
        Amounts memory amounts = staking.amountStakedByUser(campaignIds.defaultCampaign, caller);

        // It should emit {SnapshotRewards}, {Transfer} and {ClaimRewards} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            timestamp,
            vars.expectedRewardsPerTokenScaled,
            caller,
            vars.expectedUserRewards,
            amounts.totalStakedAmount
        );
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(staking), caller, vars.expectedUserRewards);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.ClaimRewards(campaignIds.defaultCampaign, caller, vars.expectedUserRewards);

        // Claim the rewards.
        uint128 actualRewards = staking.claimRewards(campaignIds.defaultCampaign);

        // It should return the rewards.
        assertEq(actualRewards, vars.expectedUserRewards, "return value");

        (vars.actualLastUpdateTime, vars.actualRewardsPerTokenScaled,) =
            staking.userSnapshot(campaignIds.defaultCampaign, caller);

        // It should set last time update to current timestamp.
        assertEq(vars.actualLastUpdateTime, timestamp, "lastUpdateTime");

        // It should set rewards to zero.
        assertEq(staking.getClaimableRewards(campaignIds.defaultCampaign, caller), 0, "rewards");

        // It should set the rewards earned per token.
        assertEq(vars.actualRewardsPerTokenScaled, vars.expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
    }
}
