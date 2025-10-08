// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { UserAccount } from "src/types/DataTypes.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract StakeLockupNFT_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(sablierStaking.stakeLockupNFT, (poolIds.defaultPool, lockup, streamIds.defaultStream));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData =
            abi.encodeCall(sablierStaking.stakeLockupNFT, (poolIds.nullPool, lockup, streamIds.defaultStream));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_EndTimeInPast() external whenNoDelegateCall whenNotNull {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInFuture.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStream);
    }

    function test_RevertWhen_EndTimeInPresent() external whenNoDelegateCall whenNotNull {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_EndTimeNotInFuture.selector, poolIds.defaultPool, END_TIME)
        );
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStream);
    }

    function test_RevertGiven_LockupNotWhitelisted() external whenNoDelegateCall whenNotNull whenEndTimeInFuture {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_LockupNotWhitelisted.selector, lockup));
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStream);
    }

    function test_RevertWhen_StreamTokenNotMatchStakingToken()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
    {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_UnderlyingTokenDifferent.selector, usdc, stakingToken)
        );
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.differentTokenStream);
    }

    function test_RevertGiven_StreamStaked()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
    {
        vm.expectRevert();
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStakedStream);
    }

    function test_RevertGiven_AmountInStreamZero()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
    {
        // Warp to the end time of the pool so that stream gets fully streamed to the recipient.
        warpStateTo(END_TIME - 1);

        // Withdraw all tokens from the stream.
        ISablierLockup(address(lockup)).withdrawMax(streamIds.defaultStream, users.recipient);

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_StakingZeroAmount.selector, poolIds.defaultPool));
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStream);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        warpStateTo(START_TIME - 1);

        _test_StakeLockupNFT({
            lockupContract: lockup,
            streamId: streamIds.defaultStream,
            expectedRptScaled: 0,
            expectedUserRewardsScaled: 0
        });
    }

    function test_WhenStartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        warpStateTo(START_TIME);

        _test_StakeLockupNFT({
            lockupContract: lockup,
            streamId: streamIds.defaultStream,
            expectedRptScaled: 0,
            expectedUserRewardsScaled: 0
        });
    }

    function test_WhenLockupImplementsGetAsset()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
        whenStartTimeInPast
    {
        _test_StakeLockupNFT({
            lockupContract: lockupV12,
            streamId: streamIds.lockupV12Stream,
            expectedRptScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedUserRewardsScaled: getScaledValue(REWARDS_EARNED_BY_RECIPIENT)
        });
    }

    function test_WhenLockupImplementsGetUnderlying()
        external
        whenNoDelegateCall
        whenNotNull
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
        whenStartTimeInPast
    {
        _test_StakeLockupNFT({
            lockupContract: lockup,
            streamId: streamIds.defaultStream,
            expectedRptScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedUserRewardsScaled: getScaledValue(REWARDS_EARNED_BY_RECIPIENT)
        });
    }

    /// @dev Helper function to test the staking of a lockup NFT.
    function _test_StakeLockupNFT(
        ISablierLockupNFT lockupContract,
        uint256 streamId,
        uint256 expectedRptScaled,
        uint256 expectedUserRewardsScaled
    )
        private
    {
        UserAccount memory initialUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);

        vars.expectedTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool) + DEFAULT_AMOUNT;

        // It should emit {SnapshotRewards}, {Transfer} and {StakeLockupNFT} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool, getBlockTimestamp(), expectedRptScaled, users.recipient, expectedUserRewardsScaled
        );
        vm.expectEmit({ emitter: address(lockupContract) });
        emit IERC721.Transfer(users.recipient, address(sablierStaking), streamId);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.StakeLockupNFT(
            poolIds.defaultPool, users.recipient, lockupContract, streamId, DEFAULT_AMOUNT
        );

        // Stake Lockup NFT.
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockupContract, streamId);

        // It should update user account.
        UserAccount memory actualUserAccount = sablierStaking.userAccount(poolIds.defaultPool, users.recipient);
        assertEq(
            actualUserAccount.streamAmountStaked,
            initialUserAccount.streamAmountStaked + DEFAULT_AMOUNT,
            "streamAmountStakedByUser"
        );
        assertEq(actualUserAccount.snapshotRptEarnedScaled, expectedRptScaled, "rptEarnedScaled");
        assertEq(
            actualUserAccount.claimableRewardsStoredScaled, expectedUserRewardsScaled, "claimableRewardsStoredScaled"
        );

        // It should increase total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.getTotalStakedAmount(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualSnapshotTime, vars.actualRptScaled) = sablierStaking.globalRptScaledAtSnapshot(poolIds.defaultPool);
        assertEq(vars.actualSnapshotTime, getBlockTimestamp(), "globalSnapshotTime");
        assertEq(vars.actualRptScaled, expectedRptScaled, "snapshotRptDistributedScaled");
    }
}
