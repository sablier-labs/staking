// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { BaseTest as EvmUtilsBase } from "@sablier/evm-utils/src/tests/BaseTest.sol";

import { Users } from "./Types.sol";

abstract contract Modifiers is EvmUtilsBase {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users private users;

    function setVariables(Users memory _users) public {
        users = _users;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       GIVEN
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenAmountInStreamNotZero() {
        _;
    }

    modifier givenDirectStakedAmountNotZero() {
        _;
    }

    modifier givenLockupWhitelisted() {
        _;
    }

    modifier givenNotCanceled() {
        _;
    }

    modifier givenNotWhitelisted() {
        _;
    }

    modifier givenStakedNFT() {
        _;
    }

    modifier givenStreamNotStaked() {
        _;
    }

    modifier givenTotalStakedNotZero() {
        _;
    }

    modifier givenWhitelisted() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        WHEN
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenAdminNotZeroAddress() {
        _;
    }

    modifier whenAmountNotExceedDirectStakedAmount() {
        _;
    }

    modifier whenAmountNotZero() {
        _;
    }

    modifier whenCallerAdmin() {
        setMsgSender(users.admin);
        _;
    }

    modifier whenCallerCampaignAdmin() {
        setMsgSender(users.campaignCreator);
        _;
    }

    modifier whenCallerHasStakedTokens() {
        _;
    }

    modifier whenCallerLockup() {
        _;
    }

    modifier whenCallerNFTOwner() {
        _;
    }

    modifier whenCallerNotAdmin() {
        _;
    }

    modifier whenClaimableRewardsNotZero() {
        _;
    }

    modifier whenEndTimeGreaterThanStartTime() {
        _;
    }

    modifier whenEndTimeInFuture() {
        _;
    }

    modifier whenEndTimeNotInPast() {
        _;
    }

    modifier whenNoDelegateCall() {
        _;
    }

    modifier whenNotNull() {
        _;
    }

    modifier whenNotZeroAddress() {
        _;
    }

    modifier whenRewardTokenNotZeroAddress() {
        _;
    }

    modifier whenStakingTokenNotZeroAddress() {
        _;
    }

    modifier whenStartTimeInFuture() {
        _;
    }

    modifier whenStartTimeInPast() {
        _;
    }

    modifier whenStartTimeNotInFuture() {
        _;
    }

    modifier whenStartTimeNotInPast() {
        _;
    }

    modifier whenStreamTokenMatchesStakingToken() {
        _;
    }

    modifier whenTotalRewardsNotZero() {
        _;
    }

    modifier whenUserNotZeroAddress() {
        _;
    }
}
