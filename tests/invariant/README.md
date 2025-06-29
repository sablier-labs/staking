## List of Invariants Implemented in [Invariant.t.sol](./Invariant.t.sol)

### Unconditional Invariants

1. The `nextPoolId` should always equal the last pool ID + 1.
2. In a pool, the sum of total rewards claimed by all users and total claimable rewards of all users should never exceed
   the expected rewards calculated without performing more than 1 division.
3. the sum of total rewards claimed by all users and total claimable rewards of all users should never exceed
   `pool.totalRewards`.
4. Global rewards distributed per token and snapshot time should never decrease over time.
5. For any user in a pool, rewards earned per token and snapshot time should never decrease over time.
6. For any user in a pool, rewards earned per tokens should never exceed global rewards distributed per token.
7. For any user in a pool, snapshot time should never exceed the global snapshot time.
8. For any user in a pool, their total staked amount should equal `directAmountStaked + streamAmountStaked`.
9. In a pool, the total staked amount should equal to the sum of total staked amount by all the users.

### Conditional Invariants

1. For any user in a pool, if unstake is called 0 times, total amount staked should never decrease over time.
2. For any user in a pool, if `stakeLockupNFT` is called 0 times, `streamAmountStaked` should always be zero.
3. For any user in a pool, if `stakeERC20Token` is called 0 times, `directAmountStaked` should always be zero.
4. When all reward tokens are distinct from staking tokens, `rewardToken.balanceOf(this)` == sum of all unclaimed
   rewards across all pool.
5. When all reward tokens are distinct from staking tokens, `stakingToken.balanceOf(this)` == the sum of all directly
   staked tokens across all pools.
