# Design Document for Staking Contract

## Features:

### For staking campaign creators

- Launch staking campaigns by specifying the ERC20 tokens.
- Campaign admin can cancel the campaign until the start time.
- The staking campaign supports multiple versions of Lockup contract as long as they implement the functions specified
  in a custom interface.

### For users who want to stake and earn rewards

- Users can stake their Sablier Lockup NFTs, which stream the allowed ERC20 tokens, to earn rewards based on the total
  amount of the ERC20 token in the stream.
- Users can also stake ERC20 tokens directly into the staking campaign.
- Users can stake multiple Lockup NFTs, or combine staking NFTs and ERC20 tokens simultaneously.
- Users can unstake their positions at any time, with the ability to stake and unstake multiple times.
- Each Lockup NFT can only be staked in one campaign at a time.
- Staked Lockup NFTs handle stream cancellations gracefully, but reverts on withdraw.
- User can claim rewards from a specific campaign.
