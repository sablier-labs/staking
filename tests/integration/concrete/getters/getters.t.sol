// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { Errors } from "src/libraries/Errors.sol";
import { GlobalSnapshot, UserSnapshot } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Getters_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
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
                               GET-CLAIMABLE-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetClaimableRewardsRevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(staking.getClaimableRewards, (campaignIds.nullCampaign, users.staker))
        });
    }

    function test_GetClaimableRewardsRevertWhen_StakerZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.getClaimableRewards(campaignIds.defaultCampaign, address(0));
    }

    function test_GetClaimableRewardsWhenRewardsZero() external view whenNotNull whenStakerNotZeroAddress {
        uint256 actualClaimableRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualClaimableRewards, 0, "actualClaimableRewards");
    }

    function test_GetClaimableRewardsWhenRewardsNotZero() external whenNotNull whenStakerNotZeroAddress {
        // Warp to 40% through the campaign.
        warpStateTo(WARP_40_PERCENT);

        // It should return non-zero.
        uint256 actualClaimableRewards = staking.getClaimableRewards(campaignIds.defaultCampaign, users.staker);
        assertEq(actualClaimableRewards, REWARDS_EARNED_BY_STAKER, "actualClaimableRewards");
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
        assertEq(address(staking.getStakingToken(campaignIds.defaultCampaign)), address(dai), "getStakingToken");
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

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(campaignIds.defaultCampaign);
        // It should return zero rewards distributed per token.
        assertEq(actualGlobalSnapshot.rewardsDistributedPerToken, 0, "rewardsDistributedPerToken");

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_AMOUNT_STAKED_PRE_START, "totalStakedTokens");

        // It should return zero last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, 0, "lastUpdateTime");
    }

    function test_GlobalSnapshotWhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(campaignIds.defaultCampaign);
        // It should return zero rewards distributed per token.
        assertEq(actualGlobalSnapshot.rewardsDistributedPerToken, 0, "rewardsDistributedPerToken");

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_AMOUNT_STAKED_START_TIME, "totalStakedTokens");

        // It should return correct last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, START_TIME, "lastUpdateTime");
    }

    function test_GlobalSnapshotWhenEndTimeInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(WARP_40_PERCENT);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(campaignIds.defaultCampaign);
        // It should return correct rewards distributed per token.
        assertEq(
            actualGlobalSnapshot.rewardsDistributedPerToken, REWARDS_DISTRIBUTED_PER_TOKEN, "rewardsDistributedPerToken"
        );

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_AMOUNT_STAKED, "totalStakedTokens");

        // It should return correct last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");
    }

    function test_GlobalSnapshotWhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct rewards distributed per token.
        assertEq(
            actualGlobalSnapshot.rewardsDistributedPerToken,
            REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME,
            "rewardsDistributedPerToken"
        );

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_AMOUNT_STAKED_END_TIME, "totalStakedTokens");

        // It should return correct last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, END_TIME, "lastUpdateTime");
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

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.staker);
        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "staker: rewardsEarnedPerToken");
        assertEq(actualUserSnapshot.rewards, 0, "staker: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_STAKER_PRE_START, "staker: totalStakedTokens");
        assertEq(
            actualUserSnapshot.stakedERC20Amount, DIRECT_AMOUNT_STAKED_BY_STAKER_PRE_START, "staker: stakedERC20Amount"
        );
        assertEq(actualUserSnapshot.stakedStreamsCount, 0, "staker: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, 0, "staker: lastUpdateTime");

        actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "recipient: rewardsEarnedPerToken");
        assertEq(actualUserSnapshot.rewards, 0, "recipient: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, 0, "recipient: totalStakedTokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, 0, "recipient: stakedERC20Amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, 0, "recipient: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, 0, "recipient: lastUpdateTime");
    }

    function test_UserSnapshotWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.staker);
        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "staker: rewardsEarnedPerToken");
        assertEq(actualUserSnapshot.rewards, 0, "staker: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_STAKER_START_TIME, "staker: totalStakedTokens");
        assertEq(
            actualUserSnapshot.stakedERC20Amount, DIRECT_AMOUNT_STAKED_BY_STAKER_START_TIME, "staker: stakedERC20Amount"
        );
        assertEq(actualUserSnapshot.stakedStreamsCount, 0, "staker: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, START_TIME, "staker: lastUpdateTime");

        actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "recipient: rewardsEarnedPerToken");
        assertEq(actualUserSnapshot.rewards, 0, "recipient: rewards");
        assertEq(
            actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_RECIPIENT_START_TIME, "recipient: totalStakedTokens"
        );
        assertEq(
            actualUserSnapshot.stakedERC20Amount,
            DIRECT_AMOUNT_STAKED_BY_RECIPIENT_START_TIME,
            "recipient: stakedERC20Amount"
        );
        assertEq(
            actualUserSnapshot.stakedStreamsCount,
            STREAMS_STAKED_BY_RECIPIENT_START_TIME,
            "recipient: stakedStreamsCount"
        );
        assertEq(actualUserSnapshot.lastUpdateTime, START_TIME, "recipient: lastUpdateTime != START_TIME");
    }

    function test_UserSnapshotWhenEndTimeInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(WARP_40_PERCENT);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.staker);
        assertEq(
            actualUserSnapshot.rewardsEarnedPerToken, REWARDS_DISTRIBUTED_PER_TOKEN, "staker: rewardsEarnedPerToken"
        );
        assertEq(actualUserSnapshot.rewards, REWARDS_EARNED_BY_STAKER, "staker: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_STAKER, "staker: totalStakedTokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, DIRECT_AMOUNT_STAKED_BY_STAKER, "staker: stakedERC20Amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, 0, "staker: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, WARP_40_PERCENT, "staker: lastUpdateTime");

        actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(
            actualUserSnapshot.rewardsEarnedPerToken, REWARDS_DISTRIBUTED_PER_TOKEN, "recipient: rewardsEarnedPerToken"
        );
        assertEq(actualUserSnapshot.rewards, REWARDS_EARNED_BY_RECIPIENT, "recipient: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_RECIPIENT, "recipient: totalStakedTokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, DIRECT_AMOUNT_STAKED_BY_RECIPIENT, "stakedERC20Amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, STREAMS_STAKED_BY_RECIPIENT, "recipient: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, WARP_40_PERCENT, "recipient: lastUpdateTime");
    }

    function test_UserSnapshotWhenEndTimeNotInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        staking.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        staking.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.staker);
        assertEq(
            actualUserSnapshot.rewardsEarnedPerToken,
            REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME,
            "staker: rewardsEarnedPerToken"
        );
        assertEq(actualUserSnapshot.rewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: totalStakedTokens");
        assertEq(
            actualUserSnapshot.stakedERC20Amount, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: stakedERC20Amount"
        );
        assertEq(actualUserSnapshot.stakedStreamsCount, 0, "staker: stakedStreamsCount");
        assertEq(actualUserSnapshot.lastUpdateTime, END_TIME, "staker: lastUpdateTime");

        actualUserSnapshot = staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(
            actualUserSnapshot.rewardsEarnedPerToken,
            REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME,
            "recipient: rewardsEarnedPerToken"
        );
        assertEq(actualUserSnapshot.rewards, REWARDS_EARNED_BY_RECIPIENT_END_TIME, "recipient: rewards");
        assertEq(
            actualUserSnapshot.totalStakedTokens, AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: totalStakedTokens"
        );
        assertEq(
            actualUserSnapshot.stakedERC20Amount,
            DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME,
            "recipient: stakedERC20Amount"
        );
        assertEq(
            actualUserSnapshot.stakedStreamsCount, STREAMS_STAKED_BY_RECIPIENT_END_TIME, "recipient: stakedStreamsCount"
        );
        assertEq(actualUserSnapshot.lastUpdateTime, END_TIME, "recipient: lastUpdateTime");
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
