// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract StakeLockupNFT_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(staking.stakeLockupNFT, (campaignIds.defaultCampaign, lockup, streamIds.defaultStream));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData =
            abi.encodeCall(staking.stakeLockupNFT, (campaignIds.nullCampaign, lockup, streamIds.defaultStream));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Canceled() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignCanceled.selector, campaignIds.canceledCampaign)
        );
        staking.stakeLockupNFT(campaignIds.canceledCampaign, lockup, streamIds.defaultStream);
    }

    function test_RevertWhen_EndTimeInPast() external whenNoDelegateCall whenNotNull givenNotCanceled {
        warpStateTo(END_TIME + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignHasEnded.selector, campaignIds.defaultCampaign, END_TIME
            )
        );
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStream);
    }

    function test_RevertWhen_EndTimeInPresent() external whenNoDelegateCall whenNotNull givenNotCanceled {
        warpStateTo(END_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CampaignHasEnded.selector, campaignIds.defaultCampaign, END_TIME
            )
        );
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStream);
    }

    function test_RevertGiven_LockupNotWhitelisted()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
    {
        // Deploy a new Lockup contract for this test.
        lockup = deployLockup();

        // It should revert.
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStaking_LockupNotWhitelisted.selector, lockup));
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStream);
    }

    function test_RevertWhen_StreamTokenNotMatchStakingToken()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
    {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_UnderlyingTokenDifferent.selector, usdc, stakingToken)
        );
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.differentTokenStream);
    }

    function test_RevertGiven_StreamStaked()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
    {
        vm.expectRevert();
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStakedStream);
    }

    function test_RevertGiven_AmountInStreamZero()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
    {
        // Warp to the end time of the campaign so that stream gets fully streamed to the recipient.
        warpStateTo(END_TIME - 1);

        // Withdraw all tokens from the stream.
        ISablierLockup(address(lockup)).withdrawMax(streamIds.defaultStream, users.recipient);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_DepletedStream.selector, lockup, streamIds.defaultStream)
        );
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStream);
    }

    function test_WhenStartTimeInFuture()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        warpStateTo(START_TIME - 1);

        _test_StakeLockupNFT({ expectedRewardsPerTokenScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        warpStateTo(START_TIME);

        _test_StakeLockupNFT({ expectedRewardsPerTokenScaled: 0, expectedUserRewards: 0 });
    }

    function test_WhenStartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotCanceled
        whenEndTimeInFuture
        givenLockupWhitelisted
        whenStreamTokenMatchesStakingToken
        givenStreamNotStaked
        givenAmountInStreamNotZero
    {
        _test_StakeLockupNFT({
            expectedRewardsPerTokenScaled: REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            expectedUserRewards: REWARDS_EARNED_BY_RECIPIENT
        });
    }

    /// @dev Helper function to test the staking of a lockup NFT.
    function _test_StakeLockupNFT(uint256 expectedRewardsPerTokenScaled, uint128 expectedUserRewards) private {
        (uint128 initialStreamsCount, uint128 initialStreamAmountStaked,) =
            staking.userShares(campaignIds.defaultCampaign, users.recipient);

        // It should emit {SnapshotRewards}, {Transfer} and {StakeLockupNFT} events.
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.SnapshotRewards(
            campaignIds.defaultCampaign,
            getBlockTimestamp(),
            expectedRewardsPerTokenScaled,
            users.recipient,
            expectedUserRewards
        );
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(users.recipient, address(staking), streamIds.defaultStream);
        vm.expectEmit({ emitter: address(staking) });
        emit ISablierStaking.StakeLockupNFT(
            campaignIds.defaultCampaign, users.recipient, lockup, streamIds.defaultStream, DEFAULT_AMOUNT
        );

        // Stake Lockup NFT.
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStream);

        // It should stake stream.
        (uint128 actualStreamsCount, uint128 actualStreamAmountStaked,) =
            staking.userShares(campaignIds.defaultCampaign, users.recipient);
        assertEq(actualStreamsCount, initialStreamsCount + 1, "streamsCount");
        assertEq(actualStreamAmountStaked, initialStreamAmountStaked + DEFAULT_AMOUNT, "streamAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);
        assertEq(globalLastUpdateTime, getBlockTimestamp(), "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            staking.userSnapshot(campaignIds.defaultCampaign, users.recipient);
        assertEq(userLastUpdateTime, getBlockTimestamp(), "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, expectedRewardsPerTokenScaled, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, expectedUserRewards, "rewards");
    }
}
