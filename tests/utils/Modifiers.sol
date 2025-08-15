// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

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

    modifier givenClaimableRewardsNotZero() {
        _;
    }

    modifier givenDirectStakedAmountNotZero() {
        _;
    }

    modifier givenLastUpdateTimeLessThanEndTime() {
        _;
    }

    modifier givenLockupWhitelisted() {
        _;
    }

    modifier givenNotWhitelisted() {
        _;
    }

    modifier givenStakedAmountNotZero() {
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

    modifier whenCallerComptroller() {
        setMsgSender(address(comptroller));
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

    modifier whenCallerPoolAdmin() {
        setMsgSender(users.poolCreator);
        _;
    }

    modifier whenEndTimeGreaterThanStartTime() {
        _;
    }

    modifier whenEndTimeInFuture() {
        _;
    }

    modifier whenEndTimeInPast() {
        _;
    }

    modifier whenEndTimeNotInPast() {
        _;
    }

    modifier whenFeeOnRewardsNotTooHigh() {
        _;
    }

    modifier whenMinFeePaid() {
        _;
    }

    modifier whenNewEndTimeGreaterThanNewStartTime() {
        _;
    }

    modifier whenNewStartTimeNotInPast() {
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
