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

        // Warp back to campaign creation date as default.
        warpStateTo(FEB_1_2025);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   EXPECT-REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(EvmUtilsErrors.DelegateCall.selector), "delegatecall return data");
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignDoesNotExist.selector, campaignIds.nullCampaign),
            "null call return data"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a default campaign.
    function createDefaultCampaign() internal returns (uint256 campaignId) {
        return staking.createCampaign({
            admin: users.campaignCreator,
            stakingToken: dai,
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
        staking.cancelCampaign(campaignIds.canceledCampaign);

        // Fresh campaign.
        campaignIds.freshCampaign = createDefaultCampaign();

        // Null campaign.
        campaignIds.nullCampaign = 420;
    }

    /// @dev This function simulates the staking behavior of the users at different times and creates EVM snapshots to
    /// be used for testing.
    function simulateAndSnapshotStakingBehavior() internal {
        // First snapshot after the campaign is created and the staker stakes direct tokens immediately.
        setMsgSender(users.staker);
        staking.stakeERC20Token(campaignIds.defaultCampaign, DEFAULT_AMOUNT);
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
