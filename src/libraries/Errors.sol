// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierLockupNFT } from "../interfaces/ISablierLockupNFT.sol";

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with.
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                               SABLIER-STAKING-STATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an unauthorized action is attempted outside the rewards period.
    error SablierStakingState_OutsideRewardsPeriod(uint256 poolId, uint40 startTime, uint40 endTime);

    /// @notice Thrown when an unauthorized action is attempted on a non-existent pool.
    error SablierStakingState_PoolDoesNotExist(uint256 poolId);

    /// @notice Thrown when the stream ID associated with the lockup contract is not staked in any pool.
    error SablierStakingState_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when zero address is used as an input argument.
    error SablierStakingState_ZeroAddress();

    /*//////////////////////////////////////////////////////////////////////////
                                  SABLIER-STAKING
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when creating a pool with admin as the zero address.
    error SablierStaking_AdminZeroAddress();

    /// @notice Thrown when unstaking an amount that exceeds the total staked amount.
    error SablierStaking_AmountExceedsStakedAmount(uint256 poolId, uint256 amountUnstaking, uint256 totalAmountStaked);

    /// @notice Thrown when the caller is not the pool admin.
    error SablierStaking_CallerNotPoolAdmin(uint256 poolId, address caller, address poolAdmin);

    /// @notice Thrown when unstaking a Lockup stream when the caller is not the original stream owner.
    error SablierStaking_CallerNotStreamOwner(
        ISablierLockupNFT lockup, uint256 streamId, address caller, address streamOwner
    );

    /// @notice Thrown when staking a Lockup stream with depleted status.
    error SablierStaking_DepletedStream(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when end time is less than the start time.
    error SablierStaking_EndTimeNotGreaterThanStartTime(uint40 startTime, uint40 endTime);

    /// @notice Thrown when staking into a pool when end time is not in the future.
    error SablierStaking_EndTimeNotInFuture(uint256 poolId, uint40 endTime);

    /// @notice Thrown when the fee paid is less than the minimum fee.
    error SablierStaking_InsufficientFeePayment(uint256 feePaid, uint256 minFee);

    /// @notice Thrown when whitelisting a lockup contract that is already whitelisted.
    error SablierStaking_LockupAlreadyWhitelisted(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when staking a Lockup stream when the associated lockup contract is not whitelisted.
    error SablierStaking_LockupNotWhitelisted(ISablierLockupNFT lockup);

    /// @notice Thrown when whitelisting the zero address.
    error SablierStaking_LockupZeroAddress(uint256 index);

    /// @notice Thrown when snapshotting rewards for a user when the user has no staked amount.
    error SablierStaking_NoStakedAmount(uint256 poolId, address user);

    /// @notice Thrown when performing an unauthorized action on a pool with rewards period active.
    error SablierStaking_RewardsPeriodActive(uint256 poolId, uint40 startTime);

    /// @notice Thrown when rewards amount is zero.
    error SablierStaking_RewardAmountZero();

    /// @notice Thrown when creating a pool with reward token as the zero address.
    error SablierStaking_RewardTokenZeroAddress();

    /// @notice Thrown when snapshotting rewards for a user when the last snapshot time exceeds the end time.
    error SablierStaking_SnapshotNotAllowed(uint256 poolId, address user, uint40 lastSnapshotTime);

    /// @notice Thrown when creating a pool with staking token as the zero address.
    error SablierStaking_StakingTokenZeroAddress();

    /// @notice Thrown when staking into a pool with zero amount.
    error SablierStaking_StakingZeroAmount(uint256 poolId);

    /// @notice Thrown when an unauthorized action is attempted on a pool when start time is in the future.
    error SablierStaking_StartTimeInFuture(uint256 poolId, uint40 startTime);

    /// @notice Thrown when start time is in the past.
    error SablierStaking_StartTimeInPast(uint40 startTime);

    /// @notice Thrown when an unauthorized action is attempted using a Lockup stream that is not staked in any pool.
    error SablierStaking_StreamNotStaked(ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when staking a Lockup stream with an underlying token different from the allowed staking token.
    error SablierStaking_UnderlyingTokenDifferent(IERC20 underlyingToken, IERC20 stakingToken);

    /// @notice Thrown when unstaking zero amount from a pool.
    error SablierStaking_UnstakingZeroAmount(uint256 poolId);

    /// @notice Thrown when whitelisting a Lockup contract that has not enabled hook call with this contract.
    error SablierStaking_UnsupportedOnAllowedToHook(uint256 index, ISablierLockupNFT lockup);

    /// @notice Thrown when the zero address is used as an input argument.
    error SablierStaking_UserZeroAddress();

    /// @notice Thrown when withdraw is attempted on a Lockup stream that is staked in a pool.
    error SablierStaking_WithdrawNotAllowed(uint256 poolId, ISablierLockupNFT lockup, uint256 streamId);

    /// @notice Thrown when the user has no rewards to claim.
    error SablierStaking_ZeroClaimableRewards(uint256 poolId, address user);
}
