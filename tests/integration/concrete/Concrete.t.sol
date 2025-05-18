// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Concrete_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal defaultCampaignId;
    uint256 internal nullStreamId = 420;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Integration_Test.setUp();

        // Create a default campaign.
        defaultCampaignId = createDefaultCampaign();

        // Stake tokens into the default campaign.
        setMsgSender(users.staker);
        staking.stakeERC20Token(defaultCampaignId, STAKED_ERC20_AMOUNT);

        // Stake the default stream into the default campaign.
        setMsgSender(users.staker);
        staking.stakeLockupNFT(defaultCampaignId, lockup, ids.defaultStakedStream);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Creates a default campaign.
    function createDefaultCampaign() internal returns (uint256 campaignId) {
        return staking.createStakingCampaign({
            admin: users.campaignCreator,
            stakingToken: dai,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: TOTAL_REWARDS_AMOUNT
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COMMON-REVERT-TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignDoesNotExist.selector, nullStreamId),
            "null call return data"
        );
    }
}
