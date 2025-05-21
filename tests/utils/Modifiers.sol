// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Users } from "./Types.sol";
import { Utils } from "./Utils.sol";

abstract contract Modifiers is Utils {
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

    modifier givenNotCanceled() {
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

    modifier whenCallerCampaignAdmin() {
        setMsgSender(users.campaignCreator);
        _;
    }

    modifier whenEndTimeGreaterThanStartTime() {
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

    modifier whenStakerNotZeroAddress() {
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

    modifier whenTotalRewardsNotZero() {
        _;
    }
}
