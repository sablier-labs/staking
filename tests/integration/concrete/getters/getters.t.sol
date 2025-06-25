// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Getters_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     GET-ADMIN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetAdminRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getAdmin, campaignIds.nullCampaign) });
    }

    function test_GetAdminWhenNotNull() external view {
        assertEq(stakingPool.getAdmin(campaignIds.defaultCampaign), users.campaignCreator, "admin");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GET-END-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetEndTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getEndTime, campaignIds.nullCampaign) });
    }

    function test_GetEndTimeWhenNotNull() external view {
        assertEq(stakingPool.getEndTime(campaignIds.defaultCampaign), END_TIME, "getEndTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GET-REWARD-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getRewardToken, campaignIds.nullCampaign) });
    }

    function test_GetRewardTokenWhenNotNull() external view {
        assertEq(
            address(stakingPool.getRewardToken(campaignIds.defaultCampaign)), address(rewardToken), "getRewardToken"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-STAKING-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStakingTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getStakingToken, campaignIds.nullCampaign) });
    }

    function test_GetStakingTokenWhenNotNull() external view {
        assertEq(
            address(stakingPool.getStakingToken(campaignIds.defaultCampaign)), address(stakingToken), "getStakingToken"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   GET-START-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStartTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getStartTime, campaignIds.nullCampaign) });
    }

    function test_GetStartTimeWhenNotNull() external view {
        assertEq(stakingPool.getStartTime(campaignIds.defaultCampaign), START_TIME, "getStartTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-TOTAL-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.getTotalRewards, campaignIds.nullCampaign) });
    }

    function test_GetTotalRewardsWhenNotNull() external view {
        assertEq(stakingPool.getTotalRewards(campaignIds.defaultCampaign), REWARD_AMOUNT, "getTotalRewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GLOBAL-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.globalSnapshot, campaignIds.nullCampaign) });
    }

    function test_GlobalSnapshotWhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = stakingPool.globalSnapshot(campaignIds.defaultCampaign);

        // It should return zero last update time.
        assertEq(lastUpdateTime, FEB_1_2025, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(
            stakingPool.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_PRE_START, "totalAmountStaked"
        );
    }

    function test_GlobalSnapshotWhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = stakingPool.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, START_TIME, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(
            stakingPool.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_START_TIME, "totalAmountStaked"
        );
    }

    function test_GlobalSnapshotWhenEndTimeInFuture() external view whenNotNull whenStartTimeInPast {
        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = stakingPool.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = REWARDS_DISTRIBUTED_PER_TOKEN_SCALED;
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(stakingPool.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.staker);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = stakingPool.globalSnapshot(campaignIds.defaultCampaign);

        // It should return correct last update time.
        assertEq(lastUpdateTime, END_TIME, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME);
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(stakingPool.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_END_TIME, "totalAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                               IS-LOCKUP-WHITELISTED
    //////////////////////////////////////////////////////////////////////////*/

    function test_IsLockupWhitelistedRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        stakingPool.isLockupWhitelisted(ISablierLockupNFT(address(0)));
    }

    function test_IsLockupWhitelistedGivenNotWhitelisted() external view whenNotZeroAddress {
        // It should return false.
        bool actualIsLockupWhitelisted = stakingPool.isLockupWhitelisted(ISablierLockupNFT(address(0x1234)));
        assertFalse(actualIsLockupWhitelisted, "whitelisted");
    }

    function test_IsLockupWhitelistedGivenWhitelisted() external view whenNotZeroAddress {
        // It should return true.
        bool actualIsLockupWhitelisted = stakingPool.isLockupWhitelisted(lockup);
        assertTrue(actualIsLockupWhitelisted, "not whitelisted");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   STREAM-LOOKUP
    //////////////////////////////////////////////////////////////////////////*/

    function test_StreamLookupRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        stakingPool.streamLookup(ISablierLockupNFT(address(0)), 0);
    }

    function test_StreamLookupRevertWhen_StreamNotStaked() external whenNotZeroAddress {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        stakingPool.streamLookup(lockup, streamIds.defaultStream);
    }

    function test_StreamLookupWhenStreamStaked() external view whenNotZeroAddress {
        // It should return the campaign ID and owner.
        (uint256 actualCampaignId, address actualOwner) =
            stakingPool.streamLookup(lockup, streamIds.defaultStakedStream);
        assertEq(actualCampaignId, campaignIds.defaultCampaign, "campaignId");
        assertEq(actualOwner, users.recipient, "owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                TOTAL-AMOUNT-STAKED
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.totalAmountStaked, campaignIds.nullCampaign) });
    }

    function test_TotalAmountStakedWhenNotNull() external {
        warpStateTo(END_TIME);
        assertEq(stakingPool.totalAmountStaked(campaignIds.defaultCampaign), TOTAL_STAKED_END_TIME, "totalAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            TOTAL-AMOUNT-STAKED-BY-USER
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedByUserRevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(stakingPool.totalAmountStakedByUser, (campaignIds.nullCampaign, users.recipient))
        });
    }

    function test_TotalAmountStakedByUserRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        stakingPool.totalAmountStakedByUser(campaignIds.defaultCampaign, address(0));
    }

    function test_TotalAmountStakedByUserWhenNotZeroAddress() external view whenNotNull {
        assertEq(
            stakingPool.totalAmountStakedByUser(campaignIds.defaultCampaign, users.recipient),
            AMOUNT_STAKED_BY_RECIPIENT,
            "totalAmountStakedByUser"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    USER-SHARES
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSharesRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.userShares, (campaignIds.nullCampaign, users.staker)) });
    }

    function test_UserSharesRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        stakingPool.userShares(campaignIds.defaultCampaign, address(0));
    }

    function test_UserSharesWhenNotZeroAddress() external whenNotNull {
        warpStateTo(END_TIME);

        (uint128 streamsCount, uint128 streamAmountStaked, uint128 directAmountStaked) =
            stakingPool.userShares(campaignIds.defaultCampaign, users.staker);
        assertEq(streamsCount, 0, "staker: streamsCount");
        assertEq(streamAmountStaked, 0, "staker: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: directAmountStaked");

        (streamsCount, streamAmountStaked, directAmountStaked) =
            stakingPool.userShares(campaignIds.defaultCampaign, users.recipient);
        assertEq(streamsCount, STREAMS_COUNT_FOR_RECIPIENT_END_TIME, "recipient: streamsCount");
        assertEq(streamAmountStaked, 2 * STREAM_AMOUNT_18D, "recipient: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: directAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   USER-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSnapshotRevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(stakingPool.userSnapshot, (campaignIds.nullCampaign, users.staker))
        });
    }

    function test_UserSnapshotRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        stakingPool.userSnapshot(campaignIds.defaultCampaign, address(0));
    }

    function test_UserSnapshotWhenStartTimeInFuture() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, FEB_1_2025, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, 0, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME);

        // Take snapshots of the rewards.
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, START_TIME, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, START_TIME, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        // Take snapshots of the rewards.
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "staker: rewardsPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_STAKER, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.recipient);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeNotInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.staker);
        stakingPool.snapshotRewards(campaignIds.defaultCampaign, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.staker);

        assertEq(lastUpdateTime, END_TIME, "staker: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "staker: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            stakingPool.userSnapshot(campaignIds.defaultCampaign, users.recipient);

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
        expectRevert_Null({ callData: abi.encodeCall(stakingPool.wasCanceled, campaignIds.nullCampaign) });
    }

    function test_WasCanceledGivenNotCanceled() external view whenNotNull {
        // It should return false.
        bool actualWasCanceled = stakingPool.wasCanceled(campaignIds.defaultCampaign);
        assertFalse(actualWasCanceled, "not canceled");
    }

    function test_WasCanceledGivenCanceled() external view whenNotNull {
        // It should return true.
        bool actualWasCanceled = stakingPool.wasCanceled(campaignIds.canceledCampaign);
        assertTrue(actualWasCanceled, "canceled");
    }
}
