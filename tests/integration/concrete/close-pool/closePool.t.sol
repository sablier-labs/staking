// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClosePool_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function setUp() public override {
        Shared_Integration_Concrete_Test.setUp();

        // Set pool creator as the default caller for this test.
        setMsgSender(users.poolCreator);
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.closePool, (poolIds.defaultPool));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertWhen_Null() external whenNoDelegateCall {
        bytes memory callData = abi.encodeCall(sablierStaking.closePool, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Closed() external whenNoDelegateCall whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.closePool(poolIds.closedPool);
    }

    function test_RevertWhen_CallerNotPoolAdmin() external whenNoDelegateCall whenNotNull givenNotClosed {
        // Change the caller to Eve.
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotPoolAdmin.selector, poolIds.defaultPool, users.eve, users.poolCreator
            )
        );
        sablierStaking.closePool(poolIds.defaultPool);
    }

    function test_RevertWhen_StartTimeInPast()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotClosed
        whenCallerPoolAdmin
    {
        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_RewardsPeriodActive.selector, poolIds.defaultPool, START_TIME)
        );
        sablierStaking.closePool(poolIds.defaultPool);
    }

    function test_RevertWhen_StartTimeInPresent()
        external
        whenNoDelegateCall
        whenNotNull
        givenNotClosed
        whenCallerPoolAdmin
    {
        warpStateTo(START_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_RewardsPeriodActive.selector, poolIds.defaultPool, START_TIME)
        );
        sablierStaking.closePool(poolIds.defaultPool);
    }

    function test_WhenStartTimeInFuture() external whenNoDelegateCall whenNotNull givenNotClosed whenCallerPoolAdmin {
        warpStateTo(START_TIME - 1);

        // It should emit {Transfer} and {closePool} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(address(sablierStaking), users.poolCreator, REWARD_AMOUNT);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.ClosePool(poolIds.defaultPool);

        // Close the pool.
        uint256 expectedAmountRefunded = sablierStaking.closePool(poolIds.defaultPool);

        // It should close the pool.
        assertEq(sablierStaking.wasClosed(poolIds.defaultPool), true, "wasClosed");

        // It should return the amount refunded.
        assertEq(expectedAmountRefunded, REWARD_AMOUNT, "return value");
    }
}
