// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

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
        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Sender cancels the stream.
    /// - Multiple values for the block timestamp from pool create time.
    /// - Caller as the NFT owner.
    function testFuzz_UnstakeLockupNFT_GivenCanceledStream(uint40 timestamp)
        external
        whenNoDelegateCall
        givenStakedNFT
        whenCallerNFTOwner
    {
        // Bound timestamp so that it is greater than the pool start time but less than the stream end time.
        timestamp = boundUint40(timestamp, START_TIME, FEB_1_2025 + STREAM_DURATION);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Get the refunded amount.
        uint128 refundedAmount = ISablierLockup(address(lockup)).refundableAmountOf(streamIds.defaultStakedStream);

        // Cancel the stream.
        setMsgSender(users.sender);
        ISablierLockup(address(lockup)).cancel(streamIds.defaultStakedStream);

        // Forward timestamp by 1 month in the future before unsablierStaking.
        timestamp += 30 days;
        vm.warp(timestamp);

        // Test unstaking the NFT.
        _test_UnstakeLockupNFT({ timestamp: timestamp, amountUnstaked: DEFAULT_AMOUNT - refundedAmount });

        // Check the stream status is canceled.
        assertTrue(ISablierLockup(address(lockup)).wasCanceled(streamIds.defaultStakedStream), "wasCanceled");
    }

    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Multiple values for the block timestamp from pool create time.
    /// - Caller as the NFT owner.
    function testFuzz_UnstakeLockupNFT(uint40 timestamp)
        external
        whenNoDelegateCall
        givenStakedNFT
        whenCallerNFTOwner
    {
        // Bound timestamp so that it is greater than the pool start time.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME + 365 days);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Test unstaking the NFT.
        _test_UnstakeLockupNFT({ timestamp: timestamp, amountUnstaked: DEFAULT_AMOUNT });
    }

    /// @dev A shared private function to test the unstaking of a Lockup NFT.
    function _test_UnstakeLockupNFT(uint40 timestamp, uint128 amountUnstaked) private {
        (uint128 previousStreamAmountStaked,) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);

        (vars.expectedRptScaled, vars.expectedUserRewards) = calculateLatestRewards(users.recipient);

        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) - amountUnstaked;

        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, timestamp, vars.expectedRptScaled, users.recipient, vars.expectedUserRewards
        );
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(address(sablierStaking), users.recipient, streamIds.defaultStakedStream);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeLockupNFT(
            poolIds.defaultPool, users.recipient, lockup, streamIds.defaultStakedStream
        );

        // Unstake Lockup NFT.
        setMsgSender(users.recipient);
        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);

        // It should unstake NFT.
        (vars.actualStreamAmountStaked,) = sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualStreamAmountStaked, previousStreamAmountStaked - amountUnstaked, "streamAmountStakedByUser");

        // It should decrease total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualsnapshotTime, vars.actualRptScaled) = sablierStaking.globalRptAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualsnapshotTime, timestamp, "actualsnapshotTime");
        assertEq(vars.actualRptScaled, vars.expectedRptScaled, "snapshotRptDistributedScaled");

        // It should update user rewards snapshot.
        (vars.actualRptScaled, vars.actualUserRewards) =
            sablierStaking.userRewards(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualRptScaled, vars.expectedRptScaled, "rptEarnedScaled");
        assertEq(vars.actualUserRewards, vars.expectedUserRewards, "rewards");
    }
}
