// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal defaultCampaignId;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Create the default campaign.
        setMsgSender(users.campaignCreator);
        defaultCampaignId = createDefaultCampaign();

        // Simulate the staking behavior of the users at different times and create EVM snapshots.
        simulateAndSnapshotStakingBehavior();

        // Set campaign creator as the default caller for concrete tests.
        setMsgSender(users.campaignCreator);

        // Warp back to pre-start time as default.
        warpStateTo(START_TIME - 1);
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

    /// @dev This function simulates the staking behavior of the users at different times and creates EVM snapshots to
    /// be used for testing.
    function simulateAndSnapshotStakingBehavior() internal {
        // First snapshot before the campaign starts: Staker stakes direct tokens at the time of campaign creation.
        setMsgSender(users.staker);
        staking.stakeERC20Token(defaultCampaignId, DEFAULT_AMOUNT);
        vm.warp(START_TIME - 1);
        snapshotState(); // snapshot ID = 0

        // Second snapshot when the campaign starts: Recipient stakes a stream.
        vm.warp(START_TIME);
        setMsgSender(users.recipient);
        staking.stakeLockupNFT(defaultCampaignId, lockup, ids.defaultStakedStream);
        snapshotState(); // snapshot ID = 1

        // When 20% through the campaign: Recipient stakes a stream and direct tokens. No snapshot is created.
        vm.warp(WARP_20_PERCENT);
        staking.stakeERC20Token(defaultCampaignId, DEFAULT_AMOUNT);
        staking.stakeLockupNFT(defaultCampaignId, lockup, ids.defaultStakedStreamNonCancelable);

        // Third snapshot when 40% through the campaign: Staker stakes direct tokens.
        vm.warp(WARP_40_PERCENT);
        setMsgSender(users.staker);
        staking.stakeERC20Token(defaultCampaignId, DEFAULT_AMOUNT);
        snapshotState(); // snapshot ID = 2

        // Fourth snapshot when 100% through the campaign.
        vm.warp(END_TIME);
        snapshotState(); // snapshot ID = 3
    }

    /// @notice Creates an EVM snapshot at the current block timestamp.
    function snapshotState() internal {
        // Snapshot rewards data.
        staking.snapshotRewards(defaultCampaignId, users.recipient);
        staking.snapshotRewards(defaultCampaignId, users.staker);

        // Snapshot EVM state.
        vm.snapshotState();
    }

    /// @dev Warps the EVM states to the given timestamp. It also changes the `block.timestamp`.
    /// @dev Reverts if the snapshot at the given timestamp does not exist.
    function warpStateTo(uint40 timestamp) internal {
        bool status;
        if (timestamp == START_TIME - 1) {
            status = vm.revertToState(0);
            require(status, "Failed to revert to snapshot 0");
        } else if (timestamp == START_TIME) {
            status = vm.revertToState(1);
            require(status, "Failed to revert to snapshot 1");
        } else if (timestamp == WARP_40_PERCENT) {
            status = vm.revertToState(2);
            require(status, "Failed to revert to snapshot 2");
        } else if (timestamp == END_TIME) {
            status = vm.revertToState(3);
            require(status, "Failed to revert to snapshot 3");
        } else {
            revert("Snapshot not found");
        }
    }
}
