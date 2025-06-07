// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Concrete_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Integration_Test.setUp();

        // Warp to 40% of the campaign duration for all concrete tests.
        warpStateTo(WARP_40_PERCENT);
    }
}
