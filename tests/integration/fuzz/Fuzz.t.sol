// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Integration_Test } from "../Integration.t.sol";

abstract contract Shared_Integration_Fuzz_Test is Integration_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address[2] internal excludedCallers;

    // 40% of fuzz tests will load input parameters from the below fixtures.
    address[2] public fixtureCaller;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Integration_Test.setUp();

        excludedCallers = [address(0), address(staking)];
        fixtureCaller = [users.recipient, users.staker];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Helper to exclude certain callers from the fuzzed input.
    function assumeNoExcludedCallers(address caller) internal view {
        for (uint256 i = 0; i < excludedCallers.length; ++i) {
            vm.assume(caller != excludedCallers[i]);
        }
    }
}
