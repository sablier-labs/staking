// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract RewardRate_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    /// @dev Checklist:
    /// - It should return the correct reward rate when the campaign is active.
    /// - It should revert when the campaign is inactive.
    function testFuzz_RewardRate(uint40 timestamp) public {
        // Warp to the EVM state at the given timestamp.
        warpStateTo(timestamp);

        if (timestamp < START_TIME || timestamp > END_TIME) {
            // It should revert.
            vm.expectRevert(
                abi.encodeWithSelector(
                    Errors.SablierStakingState_CampaignNotActive.selector,
                    campaignIds.defaultCampaign,
                    START_TIME,
                    END_TIME
                )
            );
            staking.rewardRate(campaignIds.defaultCampaign);
        } else {
            // It should return the correct reward rate.
            uint128 actualRewardRate = staking.rewardRate(campaignIds.defaultCampaign);
            assertEq(actualRewardRate, REWARD_RATE, "reward rate");
        }
    }
}
