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

    modifier givenWhitelisted() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        WHEN
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenStakerNotZeroAddress() {
        _;
    }

    modifier whenNotNull() {
        _;
    }

    modifier whenNotZeroAddress() {
        _;
    }
}
