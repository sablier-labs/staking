// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { StdInvariant } from "forge-std/src/StdInvariant.sol";

import { Base_Test } from "../Base.t.sol";
import { StakingHandler } from "./handlers/StakingHandler.sol";
import { HandlerStore } from "./stores/HandlerStore.sol";

contract Invariant_Test is Base_Test, StdInvariant {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    StakingHandler public stakingHandler;
    HandlerStore public handlerStore;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Base_Test.setUp();

        // Deploy the handlers and the associated store.
        handlerStore = new HandlerStore();
        stakingHandler = new StakingHandler(handlerStore, sablierStaking, tokens);

        // Label the contracts.
        vm.label({ account: address(handlerStore), newLabel: "handlerStore" });
        vm.label({ account: address(stakingHandler), newLabel: "stakingHandler" });

        // Target the staking handler for invariant testing.
        targetContract(address(stakingHandler));

        // Prevent these contracts from being fuzzed as `msg.sender`.
        excludeSender(address(handlerStore));
        excludeSender(address(sablierStaking));
        excludeSender(address(stakingHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                              UNCONDITIONAL INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The `nextPoolId` should always equal the current pool ID + 1.
    function invariant_NextPoolId() external view {
        if (handlerStore.totalPools() == 0) {
            return;
        }

        uint256 lastPoolId = handlerStore.lastPoolId();
        uint256 nextPoolId = sablierStaking.nextPoolId();
        assertEq(nextPoolId, lastPoolId + 1, "Invariant violation: next pool ID not incremented");
    }
}
