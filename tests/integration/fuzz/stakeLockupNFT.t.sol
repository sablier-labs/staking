// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { UserAccount } from "src/types/DataTypes.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract StakeLockupNFT_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Given enough fuzz runs, all of the following scenarios will be fuzzed:
    /// - Different callers with different amounts staked through Lockup stream.
    /// - Multiple values for the block timestamp from pool create time until the end time.
    function testFuzz_StakeLockupNFT(
        uint128 amount,
        address caller,
        uint40 timestamp
    )
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        assumeNoExcludedCallers(caller);

        // Bound amount such that it does not overflow uint128.
        amount = boundUint128(amount, 1e18, MAX_UINT128 - MAX_AMOUNT_STAKED);

        // Bound timestamp so that it is less than the end time.
        timestamp = boundUint40(timestamp, FEB_1_2025, END_TIME - 1);

        // Warp EVM state to the given timestamp.
        warpStateTo(timestamp);

        // Change caller and create a stream to stake.
        uint256 streamId = defaultCreateWithDurationsLL({ amount: amount, recipient: caller });

        setMsgSender(caller);
        IERC721(address(lockup)).setApprovalForAll({ operator: address(sablierStaking), approved: true });

        (vars.expectedRptScaled, vars.expectedUserRewards) = calculateLatestRewards(caller);
        UserAccount memory initialUserAccount = sablierStaking.userAccount(poolIds.defaultPool, caller);

        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) + amount;

        // It should emit {SnapshotRewards}, {Transfer} and {StakeLockupNFT} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, timestamp, vars.expectedRptScaled, caller, vars.expectedUserRewards
        );
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(caller, address(sablierStaking), streamId);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.StakeLockupNFT(poolIds.defaultPool, caller, lockup, streamId, amount);

        // Stake Lockup NFT.
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamId);

        // It should update user account.
        UserAccount memory actualUserAccount = sablierStaking.userAccount(poolIds.defaultPool, caller);
        assertEq(
            actualUserAccount.streamAmountStaked,
            initialUserAccount.streamAmountStaked + amount,
            "streamAmountStakedByUser"
        );
        assertEq(actualUserAccount.snapshotRptEarnedScaled, vars.expectedRptScaled, "rptEarnedScaled");
        assertEq(actualUserAccount.snapshotRewards, vars.expectedUserRewards, "rewards");

        // It should increase total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");
    }
}
