## List of Invariants Implemented in [Invariant.t.sol](./Invariant.t.sol)

1. Next pool ID = Current pool ID + 1.

2. Global rewards distributed per token and snapshot time should never decrease over time.

3. For a token:
   - contract balance = $`\sum_{pools}`$ (Total rewards deposited + Total direct staked - Total rewards claimed).

4. For a pool:
   - Total rewards claimed + Total claimable rewards $`\le`$ Total rewards deposited.
   - Total staked amount = $`\sum`$ Total staked amount by each user.

5. For a user in a pool:
   - Rewards earned per token and snapshot time should never decrease over time.
   - Rewards earned per tokens should never exceed global rewards distributed per token.
   - Staked amount should equal direct staked + stream amount staked.
   - If unstake is called 0 times, total amount staked should never decrease over time.
   - If `stakeLockupNFT` is called 0 times, `streamAmountStaked` should always be zero.
   - If `stakeERC20Token` is called 0 times, `directAmountStaked` should always be zero.

6. State transitions:
   - SCHEDULED $`\not\to`$ ENDED
   - ACTIVE $`\not\to`$ SCHEDULED
