# Architecture

## Overview

The Sablier Staking protocol distribute rewards to users over time who stake ERC20 tokens in campaigns. The protocol
supports two types of staking:

1. **Direct ERC20 Token Staking**: Users can directly stake ERC20 tokens.
2. **Lockup NFT Staking**: Users can stake Sablier Lockup NFTs that are streaming the supported staking token.

The protocol implements a snapshot-based reward calculation mechanism.

## Technical Design

### 1. Snapshot-Based Reward System

The protocol uses a snapshot mechanism to calculate user rewards:

#### Global Snapshots

- Track cumulative rewards distributed per token across all users
- Updated whenever any user interacts with the campaign

#### User Snapshots

- Store user-specific reward earned
- Calculate pending rewards as difference between global and last user snapshots
- Only updated when an action is performed on behalf of the user

```math
\text{user rewards since last snapshot} = (\text{global rewards per token} - \text{user rewards per token at last snapshot}) \cdot \text{user staked amount}
```

### 2. Dual Staking Model

#### Direct ERC20 Staking

- Users stakes tokens directly to the contract
- Rewards earned on the amount staked

#### Lockup NFT Staking

- Users stakes stream NFTs into the contract
- Rewards earned on the total tokens in the stream (including both locked and unlocked)
- Prevents withdrawal from staked streams
- Handles stream cancellation events

### 3. Campaign lifecycle

A campaign ends when one of the following two events occur:

- Campaign creator cancels it before the campaign start time
- Campaign reaches its end time

### 4. Other Considerations

- **Scaling Factor**: Amounts are scaled to 1e20 decimals for higher precision during divisions.
- **No Staking**: No rewards are distributed when no tokens are staked
