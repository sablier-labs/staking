// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Errors as EvmUtilsErrors } from "@sablier/evm-utils/src/libraries/Errors.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Base_Test } from "../Base.t.sol";
import { PoolIds } from "../utils/Types.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    PoolIds internal poolIds;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Set up default pools.
        setupDefaultPools();

        // Simulate the staking behavior of the users at different times and create EVM snapshots.
        simulateAndSnapshotStakingBehavior();

        // Set recipient as the default caller for concrete tests.
        setMsgSender(users.recipient);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   EXPECT-REVERTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(sablierStaking).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(EvmUtilsErrors.DelegateCall.selector), "delegatecall error");
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(sablierStaking).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierStakingState_PoolDoesNotExist.selector, poolIds.nullPool),
            "non-existent pool"
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Calculate latest rewards for a user.
    function calculateLatestRewards(address user)
        internal
        view
        returns (uint256 rewardsEarnedPerTokenScaled, uint128 rewards)
    {
        if (getBlockTimestamp() <= START_TIME) {
            return (0, 0);
        }

        (uint40 lastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);

        // Calculate starting point in time for rewards calculation.
        uint40 startingPointInTime = lastUpdateTime >= START_TIME ? lastUpdateTime : START_TIME;

        // Calculate time elapsed.
        uint40 timeElapsed =
            getBlockTimestamp() >= END_TIME ? END_TIME - startingPointInTime : getBlockTimestamp() - startingPointInTime;

        // Calculate global rewards distributed since last update.
        uint128 rewardsDistributedSinceLastUpdate = REWARD_AMOUNT * timeElapsed / REWARD_PERIOD;

        // Update global rewards distributed per token scaled.
        rewardsDistributedPerTokenScaled +=
            getScaledValue(rewardsDistributedSinceLastUpdate) / sablierStaking.totalAmountStaked(poolIds.defaultPool);

        // Get user rewards snapshot.
        (, rewardsEarnedPerTokenScaled, rewards) = sablierStaking.userSnapshot(poolIds.defaultPool, user);

        // Calculate latest rewards earned per token scaled.
        uint256 rewardsEarnedPerTokenScaledDelta = rewardsDistributedPerTokenScaled - rewardsEarnedPerTokenScaled;
        rewardsEarnedPerTokenScaled += rewardsEarnedPerTokenScaledDelta;

        // Calculate latest rewards for user.
        uint128 totalAmountStakedByUser = sablierStaking.totalAmountStakedByUser(poolIds.defaultPool, user);
        rewards += getDescaledValue(rewardsEarnedPerTokenScaledDelta * totalAmountStakedByUser);
    }

    /// @notice Creates a default pool.
    function createDefaultPool() internal returns (uint256 poolId) {
        return sablierStaking.createPool({
            admin: users.poolCreator,
            stakingToken: stakingToken,
            startTime: START_TIME,
            endTime: END_TIME,
            rewardToken: rewardToken,
            totalRewards: REWARD_AMOUNT
        });
    }

    /// @notice Creates the default pools and populates the Pool IDs struct.
    function setupDefaultPools() internal {
        setMsgSender(users.poolCreator);

        // Default pool.
        poolIds.defaultPool = createDefaultPool();

        // Closed pool.
        poolIds.closedPool = createDefaultPool();

        // Fresh pool.
        poolIds.freshPool = createDefaultPool();

        // Null pool.
        poolIds.nullPool = 420;
    }

    /// @dev This function simulates the staking behavior of the users at different times and creates EVM snapshots to
    /// be used for testing.
    function simulateAndSnapshotStakingBehavior() internal {
        // First snapshot after the pools are created and the staker stakes direct tokens immediately.
        setMsgSender(users.staker);
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
        sablierStaking.stakeERC20Token(poolIds.closedPool, DEFAULT_AMOUNT);

        // Close the `poolIds.closedPool` before snapshot.
        setMsgSender(users.poolCreator);
        sablierStaking.closePool(poolIds.closedPool);

        snapshotState(); // snapshot ID = 0

        // Second snapshot when the rewards period starts: Recipient stakes a stream.
        vm.warp(START_TIME);
        setMsgSender(users.recipient);
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStakedStream);
        snapshotState(); // snapshot ID = 1

        // Third snapshot when 20% through the rewards period: Recipient stakes a stream and direct tokens.
        vm.warp(WARP_20_PERCENT);
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStakedStreamNonCancelable);
        snapshotState(); // snapshot ID = 2

        // Fourth snapshot when 40% through the rewards period: Staker stakes direct tokens.
        vm.warp(WARP_40_PERCENT);
        setMsgSender(users.staker);
        sablierStaking.stakeERC20Token(poolIds.defaultPool, DEFAULT_AMOUNT);
        snapshotState(); // snapshot ID = 3
    }
}
