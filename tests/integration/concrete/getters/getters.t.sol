// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Amounts } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Getters_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    /*//////////////////////////////////////////////////////////////////////////
                               AMOUNT-STAKED-BY-USER
    //////////////////////////////////////////////////////////////////////////*/

    function test_AmountStakedByUserRevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(staking.amountStakedByUser, (campaignIds.nullCampaign, users.staker))
        });
    }

    function test_AmountStakedByUserRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.amountStakedByUser(campaignIds.defaultCampaign, address(0));
    }

    function test_AmountStakedByUserWhenNotZeroAddress() external whenNotNull {
        warpStateTo(END_TIME);

        Amounts memory amounts = staking.amountStakedByUser(campaignIds.defaultCampaign, users.staker);
        assertEq(amounts.streamsCount, 0, "staker: streamsCount");
        assertEq(amounts.directAmountStaked, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: directAmountStaked");
        assertEq(amounts.streamAmountStaked, 0, "staker: streamAmountStaked");
        assertEq(amounts.totalAmountStaked, AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: totalAmountStaked");

        amounts = staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        assertEq(amounts.streamsCount, STREAMS_COUNT_FOR_RECIPIENT_END_TIME, "recipient: streamsCount");
        assertEq(
            amounts.directAmountStaked, DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: directAmountStaked"
        );
        assertEq(amounts.streamAmountStaked, 2 * STREAM_AMOUNT_18D, "recipient: streamAmountStaked");
        assertEq(amounts.totalAmountStaked, AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: totalAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     GET-ADMIN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetAdminRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getAdmin, campaignIds.nullCampaign) });
    }

    function test_GetAdminWhenNotNull() external view {
        assertEq(staking.getAdmin(campaignIds.defaultCampaign), users.campaignCreator, "admin");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GET-END-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetEndTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getEndTime, campaignIds.nullCampaign) });
    }

    function test_GetEndTimeWhenNotNull() external view {
        assertEq(staking.getEndTime(campaignIds.defaultCampaign), END_TIME, "getEndTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GET-REWARD-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getRewardToken, campaignIds.nullCampaign) });
    }

    function test_GetRewardTokenWhenNotNull() external view {
        assertEq(address(staking.getRewardToken(campaignIds.defaultCampaign)), address(rewardToken), "getRewardToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-STAKING-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStakingTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getStakingToken, campaignIds.nullCampaign) });
    }

    function test_GetStakingTokenWhenNotNull() external view {
        assertEq(
            address(staking.getStakingToken(campaignIds.defaultCampaign)), address(stakingToken), "getStakingToken"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   GET-START-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStartTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getStartTime, campaignIds.nullCampaign) });
    }

    function test_GetStartTimeWhenNotNull() external view {
        assertEq(staking.getStartTime(campaignIds.defaultCampaign), START_TIME, "getStartTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-TOTAL-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getTotalRewards, campaignIds.nullCampaign) });
    }

    function test_GetTotalRewardsWhenNotNull() external view {
        assertEq(staking.getTotalRewards(campaignIds.defaultCampaign), REWARD_AMOUNT, "getTotalRewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GLOBAL-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.globalSnapshot, campaignIds.nullCampaign) });
    }

    function test_GlobalSnapshotWhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = staking.globalSnapshot(campaignIds.defaultCampaign);

        // It should return zero last update time.
        assertEq(lastUpdateTime, FEB_1_2025, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(staking.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_PRE_START, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = staking.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, START_TIME, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(staking.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_START_TIME, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenEndTimeInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(WARP_40_PERCENT);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = staking.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN);
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(staking.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = staking.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, END_TIME, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME);
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(staking.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_END_TIME, "totalAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                               IS-LOCKUP-WHITELISTED
    //////////////////////////////////////////////////////////////////////////*/

    function test_IsLockupWhitelistedRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.isLockupWhitelisted(ISablierLockupNFT(address(0)));
    }

    function test_IsLockupWhitelistedGivenNotWhitelisted() external view whenNotZeroAddress {
        // It should return false.
        bool actualIsLockupWhitelisted = staking.isLockupWhitelisted(ISablierLockupNFT(address(0x1234)));
        assertFalse(actualIsLockupWhitelisted, "whitelisted");
    }

    function test_IsLockupWhitelistedGivenWhitelisted() external view whenNotZeroAddress {
        // It should return true.
        bool actualIsLockupWhitelisted = staking.isLockupWhitelisted(lockup);
        assertTrue(actualIsLockupWhitelisted, "not whitelisted");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   STAKED-STREAM
    //////////////////////////////////////////////////////////////////////////*/

    function test_StakedStreamRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.stakedStream(ISablierLockupNFT(address(0)), 0);
    }

    function test_StakedStreamRevertGiven_NotWhitelisted() external whenNotZeroAddress {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_LockupNotWhitelisted.selector, address(0x1234))
        );
        staking.stakedStream(ISablierLockupNFT(address(0x1234)), 0);
    }

    function test_StakedStreamRevertWhen_StreamNotStaked() external whenNotZeroAddress givenWhitelisted {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        staking.stakedStream(lockup, streamIds.defaultStream);
    }

    function test_StakedStreamWhenStreamStaked() external whenNotZeroAddress givenWhitelisted {
        warpStateTo(WARP_40_PERCENT);

        // It should return the campaign ID and owner.
        (uint256 actualCampaignId, address actualOwner) = staking.stakedStream(lockup, streamIds.defaultStakedStream);
        assertEq(actualCampaignId, campaignIds.defaultCampaign, "campaignId");
        assertEq(actualOwner, users.recipient, "owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                TOTAL-STAKED-TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.totalAmountStaked, campaignIds.nullCampaign) });
    }

    function test_TotalAmountStakedWhenNotNull() external {
        warpStateTo(END_TIME);
        assertEq(staking.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_END_TIME, "totalAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   USER-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.userSnapshot, (campaignIds.nullCampaign, users.staker)) });
    }

    function test_UserSnapshotRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.userSnapshot(campaignIds.defaultCampaign, address(0));
    }

    function test_UserSnapshotWhenStartTimeInFuture() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, FEB_1_2025, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, 0, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, START_TIME, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, START_TIME, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(WARP_40_PERCENT);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN), "staker: rewardsPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_STAKER, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "recipient: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled, getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN), "recipient: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeNotInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, END_TIME, "staker: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "staker: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, END_TIME, "recipient: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "recipient: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT_END_TIME, "recipient: rewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    WAS-CANCELED
    //////////////////////////////////////////////////////////////////////////*/

    function test_WasCanceledRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.wasCanceled, campaignIds.nullCampaign) });
    }

    function test_WasCanceledGivenNotCanceled() external view whenNotNull {
        // It should return false.
        bool actualWasCanceled = staking.wasCanceled(campaignIds.defaultCampaign);
        assertFalse(actualWasCanceled, "not canceled");
    }

    function test_WasCanceledGivenCanceled() external view whenNotNull {
        // It should return true.
        bool actualWasCanceled = staking.wasCanceled(campaignIds.canceledCampaign);
        assertTrue(actualWasCanceled, "canceled");
    }
}
