// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    function invariant_NextPoolId() external view {
        if (handlerStore.totalPools() == 0) {
            return;
        }

        uint256 lastPoolId = handlerStore.lastPoolId();
        uint256 nextPoolId = sablierStaking.nextPoolId();
        assertEq(nextPoolId, lastPoolId + 1, "Invariant violation: next pool ID not incremented");
    }

    function invariant_GlobalSnapshot() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            (uint40 snapshotTime, uint256 currentRewardsPerToken) = sablierStaking.globalSnapshot(poolId);
            uint40 previousSnapshotTime = handlerStore.globalSnapshotTime(poolId);
            uint256 previousRewardsPerToken = handlerStore.globalRewardsPerTokenScaled(poolId);

            assertGe(snapshotTime, previousSnapshotTime, "Invariant violation: global snapshot time decreased");

            assertGe(
                currentRewardsPerToken,
                previousRewardsPerToken,
                "Invariant violation: global rewards per token decreased"
            );
        }
    }

    function invariant_ContractBalanceEqInMinusOut() external view {
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];

            // Get the contract balance of the token.
            uint256 contractBalance = token.balanceOf(address(sablierStaking));

            uint128 totalRewardsDeposited;
            uint128 totalRewardsClaimed;
            uint128 totalDirectStaked;

            for (uint256 j = 0; j < handlerStore.totalPools(); ++j) {
                uint256 poolId = handlerStore.poolIds(j);

                // If the pool's reward token is the same as the token, calculate the total rewards deposited and
                // total rewards claimed.
                if (sablierStaking.getRewardToken(handlerStore.poolIds(j)) == token) {
                    totalRewardsDeposited += handlerStore.totalRewardsDeposited(poolId);
                    for (uint256 u = 0; u < handlerStore.totalStakers(poolId); ++u) {
                        address staker = handlerStore.poolStakers(poolId, u);
                        totalRewardsClaimed += handlerStore.rewardsClaimed(poolId, staker);
                    }
                }

                // If the pool's staking token is the same as the token, calculate the total direct staked.
                if (sablierStaking.getStakingToken(handlerStore.poolIds(j)) == token) {
                    for (uint256 u = 0; u < handlerStore.totalStakers(poolId); ++u) {
                        address staker = handlerStore.poolStakers(poolId, u);
                        totalDirectStaked += handlerStore.amountStaked(poolId, staker);
                    }
                }
            }

            assertEq(
                contractBalance,
                totalRewardsDeposited + totalDirectStaked - totalRewardsClaimed,
                "Invariant violation: contract balance != total rewards deposited + total direct staked - total rewards claimed"
            );
        }
    }

    function invariant_PoolRewardsEqClaimedPlusClaimable() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint128 rewardsEarnedByAllStakers;
            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                uint128 rewardsClaimed = handlerStore.rewardsClaimed(poolId, staker);
                uint128 claimableRewards = sablierStaking.claimableRewards(poolId, staker);
                uint128 totalRewardsEarnedByUser = rewardsClaimed + claimableRewards;
                rewardsEarnedByAllStakers += totalRewardsEarnedByUser;
            }
            uint128 rewardsDeposited = handlerStore.totalRewardsDeposited(poolId);

            assertLe(
                rewardsEarnedByAllStakers,
                rewardsDeposited,
                "Invariant violation: rewardsClaimed + claimableRewards > total rewards deposited"
            );
        }
    }

    function invariant_TotalStakedAmount() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint128 totalAmountStakedInPool = sablierStaking.getTotalStakedAmount(poolId);
            uint128 totalAmountStakedByUser;
            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                totalAmountStakedByUser += sablierStaking.totalAmountStakedByUser(poolId, staker);
            }

            assertEq(
                totalAmountStakedInPool,
                totalAmountStakedByUser,
                "Invariant violation: total amount staked != sum of total amount staked by users"
            );
        }
    }

    function invariant_UserSnapshot() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                (uint40 snapshotTime, uint256 currentRewardsPerToken,) = sablierStaking.userSnapshot(poolId, staker);
                uint40 previousSnapshotTime = handlerStore.userSnapshotTime(poolId, staker);
                uint256 previousRewardsPerToken = handlerStore.userRewardsPerTokenScaled(poolId, staker);

                assertGe(snapshotTime, previousSnapshotTime, "Invariant violation: user snapshot time decreased");

                assertGe(
                    currentRewardsPerToken,
                    previousRewardsPerToken,
                    "Invariant violation: user rewards per token decreased"
                );
            }
        }
    }

    function invariant_UserSnapshotLeGlobalSnapshot() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            (uint40 globalSnapshotTime, uint256 globalRewardsPerToken) = sablierStaking.globalSnapshot(poolId);

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                (uint40 userLastTimeUpdate, uint256 userRewardsPerToken,) = sablierStaking.userSnapshot(poolId, staker);

                assertLe(
                    userLastTimeUpdate,
                    globalSnapshotTime,
                    "Invariant violation: user snapshot time > global snapshot time"
                );

                assertLe(
                    userRewardsPerToken,
                    globalRewardsPerToken,
                    "Invariant violation: user rewards per token > global rewards per token"
                );
            }
        }
    }

    function invariant_UserStakedEqDirectPlusStream() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                uint128 totalAmountStakedByUser = sablierStaking.totalAmountStakedByUser(poolId, staker);

                (, uint128 streamAmountStakedByUser, uint128 directAmountStakedByUser) =
                    sablierStaking.userShares(poolId, staker);

                assertEq(
                    totalAmountStakedByUser,
                    streamAmountStakedByUser + directAmountStakedByUser,
                    "Invariant violation: user total amount staked != user direct amount staked + user stream amount staked"
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                               CONDITIONAL INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/

    function invariant_AmountStaked_WhenUnstakeNotCalled() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint256 unstakeCalls =
                stakingHandler.calls(poolId, "unstakeERC20Token") + stakingHandler.calls(poolId, "unstakeLockupNFT");

            if (unstakeCalls == 0) {
                for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                    address staker = handlerStore.poolStakers(poolId, j);
                    uint128 amountStakedByUser = sablierStaking.totalAmountStakedByUser(poolId, staker);
                    uint128 previousAmountStakedByUser = handlerStore.amountStaked(poolId, staker);

                    assertGe(
                        amountStakedByUser, previousAmountStakedByUser, "invariant violation: amount staked decreased"
                    );
                }
            }
        }
    }

    function invariant_StreamAmountStaked_WhenStakeLockupNFTNotCalled() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint256 stakeLockupNFTCalls = stakingHandler.calls(poolId, "stakeLockupNFT");

            if (stakeLockupNFTCalls == 0) {
                for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                    address staker = handlerStore.poolStakers(poolId, j);
                    (, uint128 streamAmountStaked,) = sablierStaking.userShares(poolId, staker);

                    assertGe(streamAmountStaked, 0, "invariant violation: streamAmountStaked != 0");
                }
            }
        }
    }

    function invariant_DirectAmountStaked_WhenStakeERC20TokenNotCalled() external view {
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            uint256 stakeERC20TokenCalls = stakingHandler.calls(poolId, "stakeERC20Token");

            if (stakeERC20TokenCalls == 0) {
                for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                    address staker = handlerStore.poolStakers(poolId, j);

                    (,, uint128 directAmountStaked) = sablierStaking.userShares(poolId, staker);

                    assertGe(directAmountStaked, 0, "invariant violation: directAmountStaked != 0");
                }
            }
        }
    }
}
