// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors as EvmUtilsErrors } from "@sablier/evm-utils/src/libraries/Errors.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Base_Test } from "../Base.t.sol";
import { CampaignIds } from "../utils/Types.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    CampaignIds internal campaignIds;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Set up default campaigns.
        setupDefaultCampaigns();

        // Simulate the staking behavior of the users at different times and create EVM snapshots.
        simulateAndSnapshotStakingBehavior();

        // Set campaign creator as the default caller for concrete tests.
        setMsgSender(users.campaignCreator);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   EXPECT-REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(EvmUtilsErrors.DelegateCall.selector), "delegatecall error");
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignDoesNotExist.selector, campaignIds.nullCampaign),
            "null campaign error"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculate latest rewards for a user.
    function calculateLatestRewards(address user)
        internal
        view
        returns (uint256 rewardsEarnedPerTokenScaled, uint128 rewards)
    {
        if (getBlockTimestamp() <= START_TIME) {
            return (0, 0);
        }

        // Get total amount staked by user and globally.
        uint128 totalAmountStaked = staking.totalAmountStaked(campaignIds.defaultCampaign);
        uint128 totalAmountStakedByUser =
            staking.amountStakedByUser(campaignIds.defaultCampaign, user).totalAmountStaked;

        (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            staking.globalSnapshot(campaignIds.defaultCampaign);

        // Calculate starting point in time for rewards calculation.
        uint40 startingPointInTime = lastUpdateTime >= START_TIME ? lastUpdateTime : START_TIME;

        // Calculate time elapsed.
        uint40 timeElapsed =
            getBlockTimestamp() >= END_TIME ? END_TIME - startingPointInTime : getBlockTimestamp() - startingPointInTime;

        // Calculate global rewards distributed since last update.
        uint128 rewardsDistributedSinceLastUpdate = REWARD_AMOUNT * timeElapsed / CAMPAIGN_DURATION;

        // Update global rewards distributed per token scaled.
        rewardsDistributedPerTokenScaled += getScaledValue(rewardsDistributedSinceLastUpdate) / totalAmountStaked;

        // Get user rewards snapshot.
        (, rewardsEarnedPerTokenScaled, rewards) = staking.userSnapshot(campaignIds.defaultCampaign, user);

        // Calculate latest rewards earned per token scaled.
        uint256 rewardsEarnedPerTokenScaledDelta = rewardsDistributedPerTokenScaled - rewardsEarnedPerTokenScaled;
        rewardsEarnedPerTokenScaled += rewardsEarnedPerTokenScaledDelta;

        // Calculate latest rewards for user.
        rewards += getDescaledValue(rewardsEarnedPerTokenScaledDelta * totalAmountStakedByUser);
    }

    /// @notice Creates a default campaign.
    function createDefaultCampaign() internal returns (uint256 campaignId) {
        return staking.createCampaign({
            admin: users.campaignCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    /// @notice Creates the default campaigns and populates the campaign IDs struct.
    function setupDefaultCampaigns() internal {
        setMsgSender(users.campaignCreator);

        // Default campaign.
        campaignIds.defaultCampaign = createDefaultCampaign();

        // Canceled campaign.
        campaignIds.canceledCampaign = createDefaultCampaign();

        // Fresh campaign.
        campaignIds.freshCampaign = createDefaultCampaign();

        // Null campaign.
        campaignIds.nullCampaign = 420;
    }

    /// @dev This function simulates the staking behavior of the users at different times and creates EVM snapshots to
    /// be used for testing.
    function simulateAndSnapshotStakingBehavior() internal {
        // First snapshot after the campaigns are created and the staker stakes direct tokens immediately.
        setMsgSender(users.staker);
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
        staking.stakeERC20Token(campaignIds.canceledCampaign, DEFAULT_AMOUNT);

        // Cancel the canceledCampaign before snapshot.
        setMsgSender(users.campaignCreator);
        staking.cancelCampaign(campaignIds.canceledCampaign);

        snapshotState(); // snapshot ID = 0

        // Second snapshot when the campaign starts: Recipient stakes a stream.
        vm.warp(START_TIME);
        setMsgSender(users.recipient);
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStakedStream);
        snapshotState(); // snapshot ID = 1

        // Third snapshot when 20% through the campaign: Recipient stakes a stream and direct tokens.
        vm.warp(WARP_20_PERCENT);
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
        staking.stakeLockupNFT(campaignIds.defaultCampaign, lockup, streamIds.defaultStakedStreamNonCancelable);
        snapshotState(); // snapshot ID = 2

        // Fourth snapshot when 40% through the campaign: Staker stakes direct tokens.
        vm.warp(WARP_40_PERCENT);
        setMsgSender(users.staker);
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
        snapshotState(); // snapshot ID = 3
    }
}
