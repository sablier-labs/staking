// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract ClaimableRewards_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.claimableRewards, (poolIds.nullPool, users.recipient));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_UserZeroAddress() external whenNotNull {
        vm.expectRevert(Errors.SablierStaking_UserZeroAddress.selector);
        sablierStaking.claimableRewards(poolIds.defaultPool, address(0));
    }

    function test_GivenStakedAmountZero() external view whenNotNull whenUserNotZeroAddress {
        uint128 actualRewards = sablierStaking.claimableRewards(poolIds.defaultPool, users.eve);
        assertEq(actualRewards, 0, "rewards");
    }

    function test_GivenClaimableRewardsZero() external whenNotNull whenUserNotZeroAddress givenStakedAmountNotZero {
        warpStateTo(START_TIME);

        uint128 actualRewards = sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient);
        assertEq(actualRewards, 0, "rewards");
    }

    function test_WhenCurrentTimeEqualsSnapshotTime()
        external
        view
        whenNotNull
        whenUserNotZeroAddress
        givenStakedAmountNotZero
        givenClaimableRewardsNotZero
    {
        uint128 actualRewards = sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }

    function test_WhenCurrentTimeExceedsSnapshotTime()
        external
        whenNotNull
        whenUserNotZeroAddress
        givenStakedAmountNotZero
        givenClaimableRewardsNotZero
    {
        // Warp the EVM state to 20% through the rewards period.
        warpStateTo(WARP_20_PERCENT);

        // Warp the time to 40% through the rewards period so that snapshot time is in the past.
        vm.warp(WARP_40_PERCENT);

        uint128 actualRewards = sablierStaking.claimableRewards(poolIds.defaultPool, users.recipient);
        assertEq(actualRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
