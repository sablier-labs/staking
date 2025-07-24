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
                                 GET-TOTAL-REWARDS
    //////////////////////////////////////////////////////////////////////////*/

    function test_GetTotalRewardsRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.getTotalRewards, poolIds.nullPool) });
    }

    function test_GetTotalRewardsWhenNotNull() external view {
        assertEq(sablierStaking.getTotalRewards(poolIds.defaultPool), REWARD_AMOUNT, "getTotalRewards");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  GLOBAL-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_GlobalSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.globalSnapshot, poolIds.nullPool) });
    }

    function test_GlobalSnapshotWhenStartTimeInFuture() external whenNotNull {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = sablierStaking.globalSnapshot(poolIds.defaultPool);

        // It should return zero last update time.
        assertEq(lastUpdateTime, FEB_1_2025, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.totalAmountStaked(poolIds.defaultPool), TOTAL_STAKED_PRE_START, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenStartTimeInPresent() external whenNotNull {
        warpStateTo(START_TIME);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = sablierStaking.globalSnapshot(poolIds.defaultPool);

        // It should return correct last update time.
        assertEq(lastUpdateTime, START_TIME, "lastUpdateTime");

        // It should return zero rewards distributed per token.
        assertEq(rewardsPerTokenScaled, 0, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.totalAmountStaked(poolIds.defaultPool), TOTAL_STAKED_START_TIME, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenEndTimeInFuture() external view whenNotNull whenStartTimeInPast {
        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = sablierStaking.globalSnapshot(poolIds.defaultPool);

        // It should return correct last update time.
        assertEq(lastUpdateTime, WARP_40_PERCENT, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = REWARDS_DISTRIBUTED_PER_TOKEN_SCALED;
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.totalAmountStaked(poolIds.defaultPool), TOTAL_STAKED, "totalAmountStaked");
    }

    function test_GlobalSnapshotWhenEndTimeNotInFuture() external whenNotNull whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take global snapshot of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled) = sablierStaking.globalSnapshot(poolIds.defaultPool);

        // It should return correct last update time.
        assertEq(lastUpdateTime, END_TIME, "lastUpdateTime");

        // It should return correct rewards distributed per token.
        uint256 expectedRewardsPerTokenScaled = getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME);
        assertEq(rewardsPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsPerTokenScaled");

        // It should return correct total amount staked.
        assertEq(sablierStaking.totalAmountStaked(poolIds.defaultPool), TOTAL_STAKED_END_TIME, "totalAmountStaked");
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
                                TOTAL-AMOUNT-STAKED
    //////////////////////////////////////////////////////////////////////////*/

    function test_TotalAmountStakedRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.totalAmountStaked, poolIds.nullPool) });
    }

    function test_TotalAmountStakedWhenNotNull() external {
        warpStateTo(END_TIME);
        assertEq(sablierStaking.totalAmountStaked(poolIds.defaultPool), TOTAL_STAKED_END_TIME, "totalAmountStaked");
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

        (uint128 streamsCount, uint128 streamAmountStaked, uint128 directAmountStaked) =
            sablierStaking.userShares(poolIds.defaultPool, users.staker);
        assertEq(streamsCount, 0, "staker: streamsCount");
        assertEq(streamAmountStaked, 0, "staker: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME, "staker: directAmountStaked");

        (streamsCount, streamAmountStaked, directAmountStaked) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(streamsCount, STREAMS_COUNT_FOR_RECIPIENT_END_TIME, "recipient: streamsCount");
        assertEq(streamAmountStaked, 2 * STREAM_AMOUNT_18D, "recipient: streamAmountStaked");
        assertEq(directAmountStaked, DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME, "recipient: directAmountStaked");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   USER-SNAPSHOT
    //////////////////////////////////////////////////////////////////////////*/

    function test_UserSnapshotRevertWhen_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(sablierStaking.userSnapshot, (poolIds.nullPool, users.staker)) });
    }

    function test_UserSnapshotRevertWhen_ZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStakingState_ZeroAddress.selector);
        sablierStaking.userSnapshot(poolIds.defaultPool, address(0));
    }

    function test_UserSnapshotWhenStartTimeInFuture() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME - 1);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.staker);

        assertEq(lastUpdateTime, FEB_1_2025, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        assertEq(lastUpdateTime, 0, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenStartTimeInPresent() external whenNotNull whenNotZeroAddress {
        warpStateTo(START_TIME);

        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.staker);

        assertEq(lastUpdateTime, START_TIME, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "staker: rewardsPerTokenScaled");
        assertEq(rewards, 0, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        assertEq(lastUpdateTime, START_TIME, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, 0, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, 0, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.staker);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "staker: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "staker: rewardsPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_STAKER, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        assertEq(lastUpdateTime, WARP_40_PERCENT, "recipient: lastUpdateTime");
        assertEq(rewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "recipient: rewardsPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "recipient: rewards");
    }

    function test_UserSnapshotWhenEndTimeNotInFuture() external whenNotNull whenNotZeroAddress whenStartTimeInPast {
        warpStateTo(END_TIME);

        // Take snapshots of the rewards.
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.staker);
        sablierStaking.snapshotRewards(poolIds.defaultPool, users.recipient);

        (uint40 lastUpdateTime, uint256 rewardsPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.staker);

        assertEq(lastUpdateTime, END_TIME, "staker: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "staker: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_STAKER_END_TIME, "staker: rewards");

        (lastUpdateTime, rewardsPerTokenScaled, rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);

        assertEq(lastUpdateTime, END_TIME, "recipient: lastUpdateTime");
        assertEq(
            rewardsPerTokenScaled,
            getScaledValue(REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME),
            "recipient: rewardsPerTokenScaled"
        );
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT_END_TIME, "recipient: rewards");
    }
}
