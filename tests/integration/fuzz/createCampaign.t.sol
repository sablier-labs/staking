// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";

import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract CreatePool_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_createPool(
        address admin,
        uint40 endTime,
        address poolCreator,
        uint40 startTime,
        uint128 totalRewards
    )
        external
        whenNoDelegateCall
        whenAdminNotZeroAddress
        whenStartTimeNotInPast
        whenEndTimeGreaterThanStartTime
        whenStakingTokenNotZeroAddress
        whenRewardTokenNotZeroAddress
        whenTotalRewardsNotZero
    {
        // Ensure the parameters are within constraints.
        vm.assume(admin != address(0) && poolCreator != address(0));
        endTime = boundUint40(endTime, getBlockTimestamp() + 1 seconds, MAX_UINT40);
        startTime = boundUint40(startTime, getBlockTimestamp(), endTime - 1);
        totalRewards = boundUint128(totalRewards, 1, MAX_UINT128);

        // Deal reward token to the pool creator.
        deal({ token: address(rewardToken), to: poolCreator, give: totalRewards });
        approveContract(address(rewardToken), poolCreator, address(sablierStaking));

        // Set the pool creator as the caller.
        setMsgSender(poolCreator);

        uint256 expectedPoolIds = sablierStaking.nextPoolId();

        // It should emit {Transfer} and {CreatePool} events.
        vm.expectEmit({ emitter: address(rewardToken) });
        emit IERC20.Transfer(poolCreator, address(sablierStaking), totalRewards);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.CreatePool({
            poolId: expectedPoolIds,
            admin: poolCreator,
            endTime: endTime,
            rewardToken: rewardToken,
            stakingToken: stakingToken,
            startTime: startTime,
            totalRewards: totalRewards
        });

        // create the pool.
        uint256 actualPoolIds = sablierStaking.createPool({
            admin: poolCreator,
            stakingToken: stakingToken,
            startTime: startTime,
            endTime: endTime,
            rewardToken: rewardToken,
            totalRewards: totalRewards
        });

        // It should create the pool.
        assertEq(actualPoolIds, expectedPoolIds, "poolId");

        // It should bump the next Pool ID.
        assertEq(sablierStaking.nextPoolId(), expectedPoolIds + 1, "nextPoolId");

        // It should set the correct pool state.
        assertEq(sablierStaking.getAdmin(actualPoolIds), poolCreator, "admin");
        assertEq(sablierStaking.getStakingToken(actualPoolIds), stakingToken, "stakingToken");
        assertEq(sablierStaking.getStartTime(actualPoolIds), startTime, "startTime");
        assertEq(sablierStaking.getEndTime(actualPoolIds), endTime, "endTime");
        assertEq(sablierStaking.getRewardToken(actualPoolIds), rewardToken, "rewardToken");
        assertEq(sablierStaking.getTotalRewards(actualPoolIds), totalRewards, "totalRewards");
    }
}
