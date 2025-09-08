// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { Status } from "../types/DataTypes.sol";
import { ISablierLockupNFT } from "./ISablierLockupNFT.sol";

/// @title ISablierStakingState
/// @notice  Contract with state variables (storage and constants) for the {SablierStaking} contract, respective getters
/// and helpful modifiers.
interface ISablierStakingState {
    /*//////////////////////////////////////////////////////////////////////////
                                READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The maximum fee that can be deducted from rewards claimed, denoted as fixed-point number where 1e18 is
    /// 100%.
    /// @dev This is a constant variable.
    function MAX_FEE_ON_REWARDS() external view returns (UD60x18);

    /// @notice Returns the admin of the given Pool ID.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getAdmin(uint256 poolId) external view returns (address);

    /// @notice Returns the end time of the given Pool ID, denoted in UNIX timestamp.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getEndTime(uint256 poolId) external view returns (uint40);

    /// @notice Returns the reward amount of the given Pool ID, denoted in token's decimals.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getRewardAmount(uint256 poolId) external view returns (uint128);

    /// @notice Returns the reward token of the given Pool ID, denoted in token's decimals.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getRewardToken(uint256 poolId) external view returns (IERC20);

    /// @notice Returns the staking token of the given Pool ID.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getStakingToken(uint256 poolId) external view returns (IERC20);

    /// @notice Returns the start time of the given Pool ID, denoted in UNIX timestamp.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getStartTime(uint256 poolId) external view returns (uint40);

    /// @notice Returns the total amount of tokens staked (both direct staking and through Sablier streams), denoted in
    /// staking token's decimals.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function getTotalStakedAmount(uint256 poolId) external view returns (uint128);

    /// @notice Retrieves the global rewards per token at snapshot time for the given Pool ID.
    /// @dev Reverts if `poolId` references a non-existent pool.
    /// @param poolId The Pool ID for the query.
    /// @return snapshotTime The time when the snapshot was taken, denoted in UNIX timestamp.
    /// @return snapshotRptDistributedScaled The amount of rewards distributed per staking token, scaled by
    /// {Helpers.SCALE_FACTOR} to minimize precision loss.
    function globalRptAtSnapshot(uint256 poolId)
        external
        view
        returns (uint40 snapshotTime, uint256 snapshotRptDistributedScaled);

    /// @notice Returns true if the lockup contract is whitelisted to stake.
    /// @dev Reverts if `lockup` is the zero address.
    function isLockupWhitelisted(ISablierLockupNFT lockup) external view returns (bool);

    /// @notice Counter for the next Pool ID, used in creating new pool.
    function nextPoolId() external view returns (uint256);

    /// @notice Returns the status of the pool.
    /// @dev Reverts if `poolId` references a non-existent pool.
    function status(uint256 poolId) external view returns (Status);

    /// @notice Lookup from a Lockup stream ID to the Pool ID and original stream owner.
    /// @dev Reverts if the lockup is the zero address or the stream ID is not staked in any pool.
    /// @param lockup The lockup contract for the query.
    /// @param streamId The stream ID for the query.
    /// @return poolId The Pool ID of the pool in which the stream is staked.
    /// @return owner The original owner of the stream.
    function streamLookup(
        ISablierLockupNFT lockup,
        uint256 streamId
    )
        external
        view
        returns (uint256 poolId, address owner);

    /// @notice Returns the total amount of tokens staked by a user (both direct staking and through Sablier streams) in
    /// the given pool, denoted in staking token's decimals.
    /// @dev Reverts if `poolId` references a non-existent pool or `user` is the zero address.
    function totalAmountStakedByUser(uint256 poolId, address user) external view returns (uint128);

    /// @notice Retrieves the user rewards at last user snapshot for the given Pool ID.
    /// @dev Reverts if `poolId` references a non-existent pool or `user` is the zero address.
    /// @param poolId The Pool ID for the query.
    /// @param user The user address for the query.
    /// @return snapshotRptEarnedScaled The amount of rewards earned per staking token, scaled by
    /// {Helpers.SCALE_FACTOR} to minimize precision loss.
    /// @return snapshotRewards The amount of claimable rewards at last user snapshot, denoted in token's decimals.
    function userRewards(
        uint256 poolId,
        address user
    )
        external
        view
        returns (uint256 snapshotRptEarnedScaled, uint128 snapshotRewards);

    /// @notice Returns the user's shares of tokens staked in a pool.
    /// @dev Reverts if `poolId` references a non-existent pool or `user` is the zero address.
    /// @param poolId The Pool ID for the query.
    /// @param user The user address for the query.
    /// @return streamAmountStaked The total amount of ERC20 tokens staked through Sablier streams, denoted in staking
    /// token's decimals.
    /// @return directAmountStaked The total amount of ERC20 tokens staked directly by the user, denoted in staking
    /// token's decimals.
    function userShares(
        uint256 poolId,
        address user
    )
        external
        view
        returns (uint128 streamAmountStaked, uint128 directAmountStaked);
}
