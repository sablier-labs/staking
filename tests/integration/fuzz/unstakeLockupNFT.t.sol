// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Amounts } from "src/types/DataTypes.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract UnstakeLockupNFT_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev It should revert because caller is not an NFT owner.
    function testFuzz_RevertWhen_CallerNotNFTOwner(address caller) external whenNoDelegateCall givenStakedNFT {
        assumeNoExcludedCallers(caller);
        vm.assume(caller != users.recipient);

        setMsgSender(caller);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotStreamOwner.selector,
                lockup,
                streamIds.defaultStakedStream,
                caller,
                users.recipient
            )
        );
        staking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Sender cancels the stream.
    /// - Multiple values for the block timestamp from campaign create time.
    /// - Caller as the NFT owner.
    function testFuzz_UnstakeLockupNFT_GivenCanceledStream(uint40 timestamp)
        external
        whenNoDelegateCall
        givenStakedNFT
        givenNotCanceled
        whenCallerNFTOwner
    {
        // Bound timestamp so that it is greater than the campaign start time but less than the stream end time.
        timestamp = boundUint40(timestamp, START_TIME, FEB_1_2025 + STREAM_DURATION);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Get the refunded amount.
        uint128 refundedAmount = ISablierLockup(address(lockup)).refundableAmountOf(streamIds.defaultStakedStream);

        // Cancel the stream.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStakedStream);

        // Forward timestamp by 1 month in the future before unstaking.
        timestamp += 30 days;
        vm.warp(timestamp);

        // Test unstaking the NFT.
        _test_UnstakeLockupNFT(timestamp, DEFAULT_AMOUNT - refundedAmount);

        // Check the stream status is canceled.
        assertTrue(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStakedStream), "wasCanceled");
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Multiple values for the block timestamp from campaign create time.
    /// - Caller as the NFT owner.
    function testFuzz_UnstakeLockupNFT(uint40 timestamp)
        external
        whenNoDelegateCall
        givenStakedNFT
        givenNotCanceled
        whenCallerNFTOwner
    {
        // Bound timestamp so that it is greater than the campaign start time.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME + 365 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Test unstaking the NFT.
        _test_UnstakeLockupNFT(timestamp, DEFAULT_AMOUNT);
    }

    /// @dev A shared private function to test the unstaking of a Lockup NFT.
    function _test_UnstakeLockupNFT(uint40 timestamp, uint128 amountUnstaked) private {
        Amounts memory previousAmounts = staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);

        uint128 expectedTotalAmountStaked = previousAmounts.totalAmountStaked - amountUnstaked;
        uint128 expectedStreamAmountStaked = previousAmounts.streamAmountStaked - amountUnstaked;
        uint256 expectedStreamsCount = previousAmounts.streamsCount - 1;

        (uint256 rewardsEarnedPerTokenScaled, uint128 rewards) = calculateLatestRewards(users.recipient);

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            timestamp,
            rewardsEarnedPerTokenScaled,
            users.recipient,
            rewards,
            previousAmounts.totalAmountStaked
        );
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(address(staking), users.recipient, streamIds.defaultStakedStream);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.UnstakeLockupNFT(
            campaignIds.defaultCampaign, users.recipient, lockup, streamIds.defaultStakedStream
        );

        // Unstake Lockup NFT.
        setMsgSender(users.recipient);
        staking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);

        // It should unstake NFT.
        Amounts memory actualAmountStakedByUser =
            staking.amountStakedByUser(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualAmountStakedByUser.totalAmountStaked, expectedTotalAmountStaked, "totalAmountStakedByUser");
        assertEq(actualAmountStakedByUser.streamAmountStaked, expectedStreamAmountStaked, "streamAmountStakedByUser");
        assertEq(actualAmountStakedByUser.streamsCount, expectedStreamsCount, "streamsCount");

        // It should update global rewards snapshot.
        (uint40 actualLastUpdateTime, uint256 actualRewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(actualLastUpdateTime, timestamp, "actualLastUpdateTime");
        assertEq(
            actualRewardsDistributedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (actualLastUpdateTime, rewardsEarnedPerTokenScaled, rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualLastUpdateTime, timestamp, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, rewardsEarnedPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, rewards, "rewards");
    }
}
