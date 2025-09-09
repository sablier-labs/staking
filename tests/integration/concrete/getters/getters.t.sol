// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Status } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract Getters_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     GET-ADMIN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetAdminRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getAdmin, poolIds.nullPool) });
    }

    function test_GetAdminWhenNotNull() external view {
        assertEq(sablierStaking.getAdmin(poolIds.defaultPool), users.poolCreator, "admin");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    GET-END-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetEndTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getEndTime, poolIds.nullPool) });
    }

    function test_GetEndTimeWhenNotNull() external view {
        assertEq(sablierStaking.getEndTime(poolIds.defaultPool), END_TIME, "getEndTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-REWARD-AMOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardAmountRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getRewardAmount, poolIds.nullPool) });
    }

    function test_GetRewardAmountWhenNotNull() external view {
        assertEq(sablierStaking.getRewardAmount(poolIds.defaultPool), REWARD_AMOUNT, "getRewardAmount");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GET-REWARD-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetRewardTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getRewardToken, poolIds.nullPool) });
    }

    function test_GetRewardTokenWhenNotNull() external view {
        assertEq(address(sablierStaking.getRewardToken(poolIds.defaultPool)), address(rewardToken), "getRewardToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 GET-STAKING-TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStakingTokenRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getStakingToken, poolIds.nullPool) });
    }

    function test_GetStakingTokenWhenNotNull() external view {
        assertEq(address(sablierStaking.getStakingToken(poolIds.defaultPool)), address(stakingToken), "getStakingToken");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   GET-START-TIME
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetStartTimeRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getStartTime, poolIds.nullPool) });
    }

    function test_GetStartTimeWhenNotNull() external view {
        assertEq(sablierStaking.getStartTime(poolIds.defaultPool), START_TIME, "getStartTime");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              GET-TOTAL-STAKED-AMOUNT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalStakedAmountRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getTotalStakedAmount, poolIds.nullPool) });
    }

    function test_GetTotalStakedAmountWhenNotNull() external {
        warpStateTo(END_TIME);
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_END_TIME, "getTotalStakedAmount"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GLOBAL-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalRptAtSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.globalRewardsPerTokenAtSnapshot, poolIds.nullPool) });
    }

    function test_GlobalRptAtSnapshotWhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRewardsPerTokenAtSnapshot(poolIds.defaultPool);

        // It should return zero snapshot time.
        assertEq(snapshotTime, FEB_1_2025, "snapshotTime");

        // It should return zero rewards distributed per token.
        assertEq(rptScaled, 0, "rptScaled");

        // It should return correct total amount staked.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_PRE_START, "getTotalStakedAmount"
        );
    }

    function test_GlobalRptAtSnapshotWhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRewardsPerTokenAtSnapshot(poolIds.defaultPool);

        // It should return correct snapshot time.
        assertEq(snapshotTime, START_TIME, "snapshotTime");

        // It should return zero rewards distributed per token.
        assertEq(rptScaled, 0, "rptScaled");

        // It should return correct total amount staked.
        assertEq(
            sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED_START_TIME, "getTotalStakedAmount"
        );
    }

    function test_GlobalRptAtSnapshotWhenEndTimeInFuture() external view whenNotNull whenStartTimeInPast {
        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRewardsPerTokenAtSnapshot(poolIds.defaultPool);

        // It should return correct snapshot time.
        assertEq(snapshotTime, WARP_40_PERCENT, "snapshotTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRptScaled = REWARDS_DISTRIBUTED_PER_TOKEN_SCALED;
        assertEq(rptScaled, expectedRptScaled, "rptScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.getTotalStakedAmount(poolIds.defaultPool), TOTAL_STAKED, "getTotalStakedAmount");
    }

    function test_GlobalRptAtSnapshotWhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);

        (uint40 snapshotTime, uint256 rptScaled) = sablierStaking.globalRewardsPerTokenAtSnapshot(poolIds.defaultPool);

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

    function test_IsLockupWhitelistedRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.isLockupWhitelisted(ISablierLockupNFT(address(0)));
    }

    function test_IsLockupWhitelistedGivenNotWhitelisted() external view whenNotZeroAddress {
        // It should return false.
        bool actualIsLockupWhitelisted = sablierStaking.isLockupWhitelisted(ISablierLockupNFT(address(0x1234)));
        assertFalse(actualIsLockupWhitelisted, "whitelisted");
    }

    function test_IsLockupWhitelistedGivenWhitelisted() external view whenNotZeroAddress {
        // It should return true.
        bool actualIsLockupWhitelisted = sablierStaking.isLockupWhitelisted(lockup);
        assertTrue(actualIsLockupWhitelisted, "not whitelisted");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       STATUS
    //////////////////////////////////////////////////////////////////////////*/

    function test_StatusRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.status, poolIds.nullPool) });
    }

    function test_StatusWhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.SCHEDULED, "status");
    }

    function test_StatusWhenEndTimeInPast() external whenNotNull whenStartTimeNotInFuture {
        warpStateTo(END_TIME + 1);
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ENDED, "status");
    }

    function test_StatusWhenEndTimeNotInPast() external view whenNotNull whenStartTimeNotInFuture {
        assertEq(sablierStaking.status(poolIds.defaultPool), Status.ACTIVE, "status");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   STREAM-LOOKUP
    //////////////////////////////////////////////////////////////////////////*/

    function test_StreamLookupRevertWhen_ZeroAddress() external {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.streamLookup(ISablierLockupNFT(address(0)), 0);
    }

    function test_StreamLookupRevertWhen_StreamNotStaked() external whenNotZeroAddress {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        sablierStaking.streamLookup(lockup, streamIds.defaultStream);
    }

    function test_StreamLookupWhenStreamStaked() external view whenNotZeroAddress {
        // It should return the Pool ID and owner.
        (uint256 actualPoolIds, address actualOwner) =
            sablierStaking.streamLookup(lockup, streamIds.defaultStakedStream);
        assertEq(actualPoolIds, poolIds.defaultPool, "poolId");
        assertEq(actualOwner, users.recipient, "owner");
    }

    /*//////////////////////////////////////////////////////////////////////////
                            TOTAL-AMOUNT-STAKED-BY-USER
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedByUserRevertWhen_Null() external {
        expectRevert_Null({
            callData: abi.encodeCall(sablierStaking.totalAmountStakedByUser, (poolIds.nullPool, users.recipient))
        });
    }

    function test_TotalAmountStakedByUserRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, address(0));
    }

    function test_TotalAmountStakedByUserWhenNotZeroAddress() external view whenNotNull {
        assertEq(
            sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, users.recipient),
            AMOUNT_STAKED_BY_RECIPIENT,
            "totalAmountStakedByUser"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   USER-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.userRewards, (poolIds.nullPool, users.staker)) });
    }

    function test_UserRewardsRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.userRewards(poolIds.defaultPool, address(0));
    }

    function test_UserRewardsWhenStartTimeInFuture() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME - 1);

        (uint256 rptScaled, uint128 rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.staker);

        assertEq(rptScaled, 0, "staker: rptScaled");
        assertEq(rewards, 0, "staker: rewards");

        (rptScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        assertEq(rptScaled, 0, "recipient: rptScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserRewardsWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME);

        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint256 rptScaled, uint128 rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.staker);

        assertEq(rptScaled, 0, "staker: rptScaled");
        assertEq(rewards, 0, "staker: rewards");

        (rptScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        assertEq(rptScaled, 0, "recipient: rptScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserRewardsWhenEndTimeInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint256 rptScaled, uint128 rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.staker);

        assertEq(rptScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "staker: rptScaled");
        assertEq(rewards, REWARDS_EARNED_BY_STAKER, "staker: rewards");

        (rptScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        assertEq(rptScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "recipient: rptScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "recipient: rewards");
    }

    function test_UserRewardsWhenEndTimeNotInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint256 rptScaled, uint128 rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.staker);

        assertEq(rptScaled, getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME), "staker: rptScaled");
        assertEq(rewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");

        (rptScaled, rewards) = sablierStaking.userRewards(poolIds.defaultPool, users.recipient);

        assertEq(rptScaled, getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME), "recipient: rptScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT_END_TIME, "recipient: rewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    USER-SHARES
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSharesRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.userShares, (poolIds.nullPool, users.staker)) });
    }

    function test_UserSharesRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.userShares(poolIds.defaultPool, address(0));
    }

    function test_UserSharesWhenNotZeroAddress() external whenNotNull {
        warpStateTo(END_TIME);

        (uint128 streamAmountStaked, uint128 directAmountStaked) =
            sablierStaking.userShares(poolIds.defaultPool, users.staker);
        assertEq(streamAmountStaked, 0, "staker: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: directAmountStaked");

        (streamAmountStaked, directAmountStaked) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(streamAmountStaked, 2 * STREAM_AMOUNT_18D, "recipient: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: directAmountStaked");
    }
}
