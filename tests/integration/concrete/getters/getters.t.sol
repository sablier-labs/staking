// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status, UserAccount } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Getters_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     GET-ADMIN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetAdmin_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getAdmin, poolIds.nullPool) });
    }

    function test_GetAdmin_WhenNotNull() external view {
        assertEq(sablierStaking.getAdmin(poolIds.defaultPool), users.poolCreator, "admin");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            GET-CUMULATIVE-REWARD-AMOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetCumulativeRewardAmount_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getCumulativeRewardAmount, poolIds.nullPool) });
    }

    function test_GetCumulativeRewardAmount_WhenNotNull() external view {
        assertEq(sablierStaking.getCumulativeRewardAmount(poolIds.defaultPool), REWARD_AMOUNT, "cumulativeRewardAmount");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GET-END-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetEndTime_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getEndTime, poolIds.nullPool) });
    }

    function test_GetEndTime_WhenNotNull() external view {
        assertEq(sablierStaking.getEndTime(poolIds.defaultPool), END_TIME, "getEndTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-REWARD-AMOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardAmount_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getRewardAmount, poolIds.nullPool) });
    }

    function test_GetRewardAmount_WhenNotNull() external view {
        assertEq(sablierStaking.getRewardAmount(poolIds.defaultPool), REWARD_AMOUNT, "getRewardAmount");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GET-REWARD-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardToken_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getRewardToken, poolIds.nullPool) });
    }

    function test_GetRewardToken_WhenNotNull() external view {
        assertEq(address(sablierStaking.getRewardToken(poolIds.defaultPool)), address(rewardToken), "getRewardToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-STAKING-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStakingToken_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getStakingToken, poolIds.nullPool) });
    }

    function test_GetStakingToken_WhenNotNull() external view {
        assertEq(address(sablierStaking.getStakingToken(poolIds.defaultPool)), address(stakingToken), "getStakingToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   GET-START-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStartTime_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getStartTime, poolIds.nullPool) });
    }

    function test_GetStartTime_WhenNotNull() external view {
        assertEq(sablierStaking.getStartTime(poolIds.defaultPool), START_TIME, "getStartTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              GET-TOTAL-STAKED-AMOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalStakedAmount_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getTotalStakedAmount, poolIds.nullPool) });
    }

    function test_GetTotalStakedAmount_WhenNotNull() external {
        warpStateTo(END_TIME);
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_END_TIME, "getTotalStakedAmount"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                           GLOBAL-RPT-SCALED-AT-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalRptScaledAtSnapshot_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.globalRptScaledAtSnapshot, poolIds.nullPool) });
    }

    function test_GlobalRptScaledAtSnapshot_WhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);

        // It should return zero snapshot time.
        assertEq(snapshotTime, FEB_1_2025, "snapshotTime");

        // It should return zero rewards distributed per token.
        assertEq(rptScaled, 0, "rptScaled");

        // It should return correct total amount staked.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_PRE_START, "getTotalStakedAmount"
        );
    }

    function test_GlobalRptScaledAtSnapshot_WhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);

        // It should return correct snapshot time.
        assertEq(snapshotTime, START_TIME, "snapshotTime");

        // It should return zero rewards distributed per token.
        assertEq(rptScaled, 0, "rptScaled");

        // It should return correct total amount staked.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_START_TIME, "getTotalStakedAmount"
        );
    }

    function test_GlobalRptScaledAtSnapshot_WhenEndTimeInFuture() external view whenNotNull whenStartTimeInPast {
        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);

        // It should return correct snapshot time.
        assertEq(snapshotTime, WARP_40_PERCENT, "snapshotTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRptScaled = REWARDS_DISTRIBUTED_PER_TOKEN_SCALED;
        assertEq(rptScaled, expectedRptScaled, "rptScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED, "getTotalStakedAmount");
    }

    function test_GlobalRptScaledAtSnapshot_WhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);

        // It should return correct snapshot time.
        assertEq(snapshotTime, END_TIME, "snapshotTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRptScaled = getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME);
        assertEq(rptScaled, expectedRptScaled, "rptScaled");

        // It should return correct total amount staked.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_END_TIME, "getTotalStakedAmount"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                               IS-LOCKUP-WHITELISTED
    //////////////////////////////////////////////////////////////////////////*/

    function test_IsLockupWhitelisted_RevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.isLockupWhitelisted(ISablierLockupNFT(address(0)));
    }

    function test_IsLockupWhitelisted_GivenNotWhitelisted() external view whenNotZeroAddress {
        // It should return false.
        bool actualIsLockupWhitelisted = sablierStaking.isLockupWhitelisted(ISablierLockupNFT(address(0x1234)));
        assertFalse(actualIsLockupWhitelisted, "whitelisted");
    }

    function test_IsLockupWhitelisted_GivenWhitelisted() external view whenNotZeroAddress {
        // It should return true.
        bool actualIsLockupWhitelisted = sablierStaking.isLockupWhitelisted(lockup);
        assertTrue(actualIsLockupWhitelisted, "not whitelisted");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       STATUS
    //////////////////////////////////////////////////////////////////////////*/

    function test_Status_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.status, poolIds.nullPool) });
    }

    function test_Status_WhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.SCHEDULED, "status");
    }

    function test_Status_WhenEndTimeInPast() external whenNotNull whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ENDED, "status");
    }

    function test_Status_WhenEndTimeNotInPast() external view whenNotNull whenStartTimeNotInFuture {
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ACTIVE, "status");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   STREAM-LOOKUP
    //////////////////////////////////////////////////////////////////////////*/

    function test_StreamLookup_RevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.streamLookup(ISablierLockupNFT(address(0)), 0);
    }

    function test_StreamLookup_RevertWhen_StreamNotStaked() external whenNotZeroAddress {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        sablierStaking.streamLookup(lockup, streamIds.defaultStream);
    }

    function test_StreamLookup_WhenStreamStaked() external view whenNotZeroAddress {
        // It should return the Pool ID and owner.
        (uint256 actualPoolIds, address actualOwner) =
            sablierStaking.streamLookup(lockup, streamIds.defaultStakedStream);
        assertEq(actualPoolIds, poolIds.defaultPool, "poolId");
        assertEq(actualOwner, users.recipient, "owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            TOTAL-AMOUNT-STAKED-BY-USER
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedByUser_RevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(sablierStaking.totalAmountStakedByUser, (poolIds.nullPool, users.recipient))
        });
    }

    function test_TotalAmountStakedByUser_RevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, address(0));
    }

    function test_TotalAmountStakedByUser_WhenNotZeroAddress() external view whenNotNull {
        assertEq(
            sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, users.recipient),
            AMOUNT_STAKED_BY_RECIPIENT,
            "totalAmountStakedByUser"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    USER-ACCOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserAccount_RevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.userAccount, (poolIds.nullPool, users.staker)) });
    }

    function test_UserAccount_RevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.userAccount(poolIds.defaultPool, address(0));
    }

    function test_UserAccount_WhenNotZeroAddress() external whenNotNull {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        UserAccount memory stakerAccount = sablierStaking.userAccount(poolIds.defaultPool, users.staker);
        assertEq(stakerAccount.streamAmountStaked, 0, "staker: streamAmountStaked");
        assertEq(
            stakerAccount.directAmountStaked, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: directAmountStaked"
        );
        assertEq(stakerAccount.snapshotRewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");
        assertEq(
            stakerAccount.snapshotRptEarnedScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "staker: rptScaled"
        );

        UserAccount memory recipientAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        assertEq(recipientAccount.streamAmountStaked, 2 * STREAM_AMOUNT_18D, "recipient: streamAmountStaked");
        assertEq(
            recipientAccount.directAmountStaked,
            DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME,
            "recipient: directAmountStaked"
        );
        assertEq(recipientAccount.snapshotRewards, REWARDS_EARNED_BY_RECIPIENT_END_TIME, "recipient: rewards");
        assertEq(
            recipientAccount.snapshotRptEarnedScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "recipient: rptScaled"
        );
    }
}
