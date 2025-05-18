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
        expectRevert_Null({ callData: abi.encodeCall(staking.getAdmin, nullStreamId) });
    }

    function test_GetAdminWhenNotNull() external view {
        assertEq(staking.getAdmin(defaultCampaignId), users.campaignCreator, "admin");
    }

    /*//////////////////////////////////////////////////////////////////////////
                               GET-CLAIMABLE-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetClaimableRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getClaimableRewards, (nullStreamId, users.staker)) });
    }

    function test_GetClaimableRewardsRevertWhen_StakerZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.getClaimableRewards(defaultCampaignId, address(0));
    }

    function test_GetClaimableRewardsWhenRewardsZero() external view whenNotNull whenStakerNotZeroAddress {
        // It should return zero.
        uint256 actualClaimableRewards = staking.getClaimableRewards(defaultCampaignId, users.staker);
        assertEq(actualClaimableRewards, 0, "zero claimable rewards");
    }

    function test_GetClaimableRewardsWhenRewardsNotZero() external whenNotNull whenStakerNotZeroAddress {
        // Warp to campaign end time so there is rewards to claim.
        vm.warp(END_TIME);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        // It should return non-zero.
        uint256 actualClaimableRewards = staking.getClaimableRewards(defaultCampaignId, users.staker);
        assertEq(actualClaimableRewards, TOTAL_REWARDS_AMOUNT, "non-zero claimable rewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GET-END-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetEndTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getEndTime, nullStreamId) });
    }

    function test_GetEndTimeWhenNotNull() external view {
        assertEq(staking.getEndTime(defaultCampaignId), END_TIME, "end time");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GET-REWARD-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getRewardToken, nullStreamId) });
    }

    function test_GetRewardTokenWhenNotNull() external view {
        assertEq(address(staking.getRewardToken(defaultCampaignId)), address(rewardToken), "reward token");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-STAKING-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStakingTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getStakingToken, nullStreamId) });
    }

    function test_GetStakingTokenWhenNotNull() external view {
        assertEq(address(staking.getStakingToken(defaultCampaignId)), address(dai), "staking token");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   GET-START-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStartTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getStartTime, nullStreamId) });
    }

    function test_GetStartTimeWhenNotNull() external view {
        assertEq(staking.getStartTime(defaultCampaignId), START_TIME, "start time");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-TOTAL-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.getTotalRewards, nullStreamId) });
    }

    function test_GetTotalRewardsWhenNotNull() external view {
        assertEq(staking.getTotalRewards(defaultCampaignId), TOTAL_REWARDS_AMOUNT, "total rewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GLOBAL-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.globalSnapshot, nullStreamId) });
    }

    function test_GlobalSnapshotWhenStartTimeInFuture() external whenNotNull {
        vm.warp(START_TIME - 1);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(defaultCampaignId);
        // It should return zero rewards distributed per token.
        assertEq(actualGlobalSnapshot.rewardsDistributedPerToken, 0, "zero rewards distributed per token");

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");

        // It should return zero last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, 0, "zero last update time");
    }

    function test_GlobalSnapshotWhenStartTimeInPresent() external whenNotNull {
        vm.warp(START_TIME);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(defaultCampaignId);
        // It should return zero rewards distributed per token.
        assertEq(actualGlobalSnapshot.rewardsDistributedPerToken, 0, "zero rewards distributed per token");

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");

        // It should return correct last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, START_TIME, "last update time");
    }

    function test_GlobalSnapshotWhenStartTimeInPast() external whenNotNull {
        vm.warp(END_TIME);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        GlobalSnapshot memory actualGlobalSnapshot = staking.globalSnapshot(defaultCampaignId);
        // It should return correct rewards distributed per token.
        assertEq(
            actualGlobalSnapshot.rewardsDistributedPerToken,
            REWARDS_DISTRIBUTED_PER_TOKEN,
            "rewards distributed per token"
        );

        // It should return correct total staked tokens.
        assertEq(actualGlobalSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");

        // It should return correct last update time.
        assertEq(actualGlobalSnapshot.lastUpdateTime, END_TIME, "last update time");
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
        assertFalse(actualIsLockupWhitelisted, "not whitelisted");
    }

    function test_IsLockupWhitelistedGivenWhitelisted() external view whenNotZeroAddress {
        // It should return true.
        bool actualIsLockupWhitelisted = staking.isLockupWhitelisted(lockup);
        assertTrue(actualIsLockupWhitelisted, "whitelisted");
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
            abi.encodeWithSelector(
                Errors.SablierStakingState_StreamNotStaked.selector, lockup, ids.defaultUnstakedStream
            )
        );
        staking.stakedStream(lockup, ids.defaultUnstakedStream);
    }

    function test_StakedStreamWhenStreamStaked() external view whenNotZeroAddress givenWhitelisted {
        // It should return the campaign ID and owner.
        (uint256 actualCampaignId, address actualOwner) = staking.stakedStream(lockup, ids.defaultStakedStream);
        assertEq(actualCampaignId, defaultCampaignId, "campaign ID");
        assertEq(actualOwner, users.staker, "owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   USER-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.userSnapshot, (nullStreamId, users.staker)) });
    }

    function test_UserSnapshotRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        staking.userSnapshot(defaultCampaignId, address(0));
    }

    function test_UserSnapshotWhenStartTimeInFuture() external whenNotNull whenNotZeroAddress {
        vm.warp(START_TIME - 1);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(defaultCampaignId, users.staker);

        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "rewards earned per token");
        assertEq(actualUserSnapshot.rewards, 0, "rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, STAKED_ERC20_AMOUNT, "staked ERC20 amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, STAKED_STREAM_COUNT, "staked streams count");
        assertEq(actualUserSnapshot.lastUpdateTime, 0, "last update time");
    }

    function test_UserSnapshotWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        vm.warp(START_TIME);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(defaultCampaignId, users.staker);

        assertEq(actualUserSnapshot.rewardsEarnedPerToken, 0, "rewards earned per token");
        assertEq(actualUserSnapshot.rewards, 0, "rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, STAKED_ERC20_AMOUNT, "staked ERC20 amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, STAKED_STREAM_COUNT, "staked streams count");
        assertEq(actualUserSnapshot.lastUpdateTime, START_TIME, "last update time");
    }

    function test_UserSnapshotWhenStartTimeInPast() external whenNotNull whenNotZeroAddress {
        vm.warp(END_TIME);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        UserSnapshot memory actualUserSnapshot = staking.userSnapshot(defaultCampaignId, users.staker);

        assertEq(actualUserSnapshot.rewardsEarnedPerToken, REWARDS_DISTRIBUTED_PER_TOKEN, "rewards earned per token");
        assertEq(actualUserSnapshot.rewards, TOTAL_REWARDS_AMOUNT, "rewards");
        assertEq(actualUserSnapshot.totalStakedTokens, TOTAL_STAKED_AMOUNT, "total staked tokens");
        assertEq(actualUserSnapshot.stakedERC20Amount, STAKED_ERC20_AMOUNT, "staked ERC20 amount");
        assertEq(actualUserSnapshot.stakedStreamsCount, STAKED_STREAM_COUNT, "staked streams count");
        assertEq(actualUserSnapshot.lastUpdateTime, END_TIME, "last update time");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    WAS-CANCELED
    //////////////////////////////////////////////////////////////////////////*/

    function test_WasCanceledRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(staking.wasCanceled, nullStreamId) });
    }

    function test_WasCanceledGivenNotCanceled() external view whenNotNull {
        // It should return false.
        bool actualWasCanceled = staking.wasCanceled(defaultCampaignId);
        assertFalse(actualWasCanceled, "not canceled");
    }

    function test_WasCanceledGivenCanceled() external whenNotNull {
        // Cancel the campaign.
        setMsgSender(users.campaignCreator);
        staking.cancelCampaign(defaultCampaignId);

        // It should return true.
        bool actualWasCanceled = staking.wasCanceled(defaultCampaignId);
        assertTrue(actualWasCanceled, "canceled");
    }
}
