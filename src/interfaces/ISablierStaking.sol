// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierLockupRecipient } from "@sablier/lockup/src/interfaces/ISablierLockupRecipient.sol";

import { GlobalRewards, SablierLockupNFT, UserRewards } from "../types/DataTypes.sol";

/// @title ISablierStaking
/// @notice A singleton contract to launch staking campaigns that can support both ERC20 tokens and Sablier Lockup NFTs.
///
/// Features:
///  - Launch staking campaigns by specifying the ERC20 tokens.
///  - Users can stake their Sablier Lockup NFTs, which stream the allowed ERC20 tokens, to earn rewards based on the
///    total amount of the ERC20 token in the stream.
///  - The staking campaign supports multiple versions of Lockup contract as long as they implement the functions
///    specified in the {ISablierLockupNFT} interface.
///  - Users can also stake ERC20 tokens directly into the staking campaign.
///  - Users can stake multiple Lockup NFTs, or combine staking NFTs and ERC20 tokens simultaneously.
///  - Users can unstake their positions at any time, with the ability to stake and unstake multiple times.
///  - Each Lockup NFT can only be staked in one campaign at a time.
///  - Staked Lockup NFTs handle stream cancellations gracefully, but reverts on withdraw.
///  - Campaign admin can cancel the campaign until the start time.
interface ISablierStaking is IERC721Receiver, ISablierLockupRecipient {
    /*//////////////////////////////////////////////////////////////////////////
                                 READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function nextCampaignId() external view returns (uint256);

    function getAdmin(uint256 campaignId) external view returns (address);
    function getEndTime(uint256 campaignId) external view returns (uint40);
    function getStakingToken(uint256 campaignId) external view returns (IERC20);
    function getStartTime(uint256 campaignId) external view returns (uint40);
    function getRewardToken(uint256 campaignId) external view returns (IERC20);
    function getTotalRewardsAmount(uint256 campaignId) external view returns (uint256);

    function globalSnapshot(uint256 campaignId) external view returns (GlobalRewards memory);

    function userSnapshot(uint256 campaignId, address user) external view returns (UserRewards memory);

    function totalStakedByUser(
        uint256 campaignId,
        address user
    )
        external
        view
        returns (uint256 totalLockupStreams, uint256 amountInLockupStream, uint256 amountInERC20);
    function rewardRatePerERC20(uint256 campaignId) external view returns (uint256);
    function rewardPerSecond(uint256 campaignId) external view returns (uint256);

    function claimableRewards(uint256 campaignId, address user) external view returns (uint256 amount);

    /// @notice {IERC165-supportsInterface} implementation as required by `ISablierLockupRecipient` interface.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
    function stakingAPY(uint256 campaignId) external view returns (UD60x18);

    /*//////////////////////////////////////////////////////////////////////////
                              STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a new staking campaign.
    /// @dev Transfers the total reward amount from the caller to the contract.
    function createStakingCampaign(
        address admin,
        IERC20 stakingToken,
        uint40 startTime,
        uint40 endTime,
        IERC20 rewardToken,
        uint128 rewardsAmount
    )
        external
        returns (uint256 campaignId);

    function cancelStakingCampaign(uint256 campaignId) external;

    function claimRewards(uint256 campaignId) external;

    /// @notice Stake the Lockup stream streaming the allowed ERC20 token in the specified campaign.
    function stakeLockupNFT(uint256 campaignId, SablierLockupNFT calldata lockupNFT) external;

    /// @notice Stake ERC20 token in the specified campaign.
    function stakeERC20token(uint256 campaignId, uint128 amount) external;

    /// @notice Unstake the Lockup stream from the specified campaign.
    function unstakeLockupNFT(SablierLockupNFT calldata lockupNFT) external;

    /// @notice Unstake the ERC20 token from the specified campaign.
    function unstakeERC20token(uint256 campaignId, uint128 amount) external;

    /// @notice Update rewards snapshot for the specified campaign and user.
    function updateRewardsSnapshot(uint256 campaignId, address user) external;
}
