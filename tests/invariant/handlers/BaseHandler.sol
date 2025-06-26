// SPDX-License-Identifier: UNLICENSED
// solhint-disable immutable-vars-naming
pragma solidity >=0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { BaseUtils } from "@sablier/evm-utils/src/tests/BaseUtils.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Constants } from "tests/utils/Constants.sol";
import { HandlerStore } from "./../stores/HandlerStore.sol";

contract BaseHandler is BaseUtils, Constants, StdCheats {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    HandlerStore public immutable handlerStore;

    ISablierStaking public immutable sablierStaking;

    /// @dev An immutable array of all the tokens used in the invariant test.
    IERC20[] public tokens;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_POOL_COUNT = 100;

    /// @dev Maps function names and the number of times they have been called on a pool.
    mapping(uint256 poolId => mapping(string func => uint256 calls)) public calls;

    /// @dev The pool ID selected for the current handler function execution.
    uint256 internal selectedPoolId;

    /// @dev The staker address selected for the current handler function execution.
    address internal selectedStaker;

    /// @dev The total number of calls made to a specific function.
    mapping(string func => uint256 calls) public totalCalls;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier adjustTimestamp(uint256 timeJump) {
        timeJump = bound(timeJump, 0, 30 days);
        skip(timeJump);

        _;
    }

    /// @dev Records a function call for instrumentation purposes.
    modifier instrument(string memory functionName) {
        _;

        calls[selectedPoolId][functionName]++;
        totalCalls[functionName]++;
    }

    modifier useFuzzedPool(uint256 poolIdIndex) {
        // Return if there are no pools.
        if (handlerStore.totalPools() == 0) {
            return;
        }

        poolIdIndex = bound(poolIdIndex, 0, handlerStore.totalPools() - 1);
        selectedPoolId = handlerStore.poolIds(poolIdIndex);

        _;
    }

    modifier useFuzzedStaker(uint256 stakerIndex) {
        uint256 totalStakers = handlerStore.totalStakers(selectedPoolId);

        // Return if there are no stakers.
        if (totalStakers == 0) {
            return;
        }

        stakerIndex = bound(stakerIndex, 0, totalStakers - 1);
        selectedStaker = handlerStore.poolStakers(selectedPoolId, stakerIndex);

        setMsgSender(selectedStaker);

        _;
    }

    /// @dev Updates the rewards distributed by all the pools in the handler store.
    modifier updateRewardsDistributedForAllPools() {
        _;

        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);

            uint128 rewardsPerSecond = sablierStaking.rewardRate(poolId);
            uint40 durationSinceLastUpdate = getBlockTimestamp() - handlerStore.rewardsDistributedAt();

            for (uint256 j = 0; j < handlerStore.totalStakers(poolId); ++j) {
                address staker = handlerStore.poolStakers(poolId, j);
                uint128 amountStakedByUser = handlerStore.amountStaked(poolId, staker);

                uint128 rewardsDistributedToUser = amountStakedByUser * rewardsPerSecond * durationSinceLastUpdate;
                handlerStore.updateRewardsDistributed(poolId, rewardsDistributedToUser);
            }
        }

        handlerStore.updateRewardsDistributedAt(getBlockTimestamp());
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(HandlerStore handlerStore_, ISablierStaking sablierStaking_, IERC20[] memory tokens_) {
        handlerStore = handlerStore_;
        sablierStaking = sablierStaking_;

        for (uint256 i = 0; i < tokens_.length; ++i) {
            tokens.push(tokens_[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Returns the amount in wei using the token's decimals.
    function amountInWei(uint128 amount, IERC20 token) internal view returns (uint128) {
        return (amount * 10 ** IERC20Metadata(address(token)).decimals()).toUint128();
    }
}
