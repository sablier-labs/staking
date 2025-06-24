## List of Invariants Implemented in [Staking.t.sol](./Staking.t.sol)

### Campaign states

1. `nextCampaignId` should always equal the current campaign ID + 1.

### Rewards

1. Total rewards distributed should be equal to the sum of the product of global rewards distributed per token and total
   amount staked at each snapshot time.
2. Total rewards distributed should never exceed `campaign.totalRewards`.
3. Total rewards earned by a user in a campaign should be equal to the sum of the product of rewards earned per token
   and amount staked by user at each user snapshot time.
4. Total rewards distributed should be equal to the sum of total rewards earned by all the users in a campaign.

### Rewards distributed per token

1. Global rewards distributed per token should never decrease over time
2. For any user in a campaign, rewards earned per token should never decrease over time
3. For any user in a campaign, rewards earned per tokens should never exceed global rewards distributed per token.

### Snapshot time

1. Global and user snapshot times should never decrease.
2. For any user in a campaign, snapshot time should never exceed the global snapshot time.

### Token Balances

1. For any user in a campaign, their total staked amount should equal `directAmountStaked + streamAmountStaked`.
2. In a campaign, the total staked amount should equal to the sum of total staked amount by all the users.
3. For any user in a campaign, if unstake is called 0 times, total amount staked should never decrease over time.
4. For any user in a campaign, if `stakeLockupNFT` is called 0 times, `streamAmountStaked` should always be zero.
5. For any user in a campaign, if `stakeERC20Token` is called 0 times, `directAmountStaked` should always be zero.
6. When all reward tokens are distinct from staking tokens, `rewardToken.balanceOf(this)` == sum of all unclaimed
   rewards across all campaigns.
7. When all reward tokens are distinct from staking tokens, `stakingToken.balanceOf(this)` == the sum of all directly
   staked tokens across all campaigns.
