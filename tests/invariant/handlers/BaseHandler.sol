// SPDX-License-Identifier: UNLICENSED
// solhint-disable immutable-vars-naming
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Utils } from "../../utils/Utils.sol";
import { HandlerStore } from "./../stores/HandlerStore.sol";

contract BaseHandler is Utils, StdCheats {
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

    /// @dev Forwards the block timestamp.
    modifier adjustTimestamp(uint256 timeJump) {
        timeJump = bound(timeJump, 0, 30 days);
        skip(timeJump);
        _;
    }

    /// @dev Calculates the rewards period for all the pools and updates it in the handler store.
    modifier updateTotalRewardsPeriodForAllPools() {
        uint40 previousCalculationTime = handlerStore.rewardsPeriodUpdatedAt();

        // Loop over all pools.
        for (uint256 i = 0; i < handlerStore.totalPools(); ++i) {
            uint256 poolId = handlerStore.poolIds(i);
            uint40 endTime = sablierStaking.getEndTime(poolId);

            // Do nothing if end time has passed or there are no stakers.
            if (previousCalculationTime < endTime && sablierStaking.totalAmountStaked(poolId) > 0) {
                uint40 durationSinceLastCalculation;
                // Keep in mind the pool end time for the duration calculation.
                if (getBlockTimestamp() > endTime) {
                    durationSinceLastCalculation = endTime - previousCalculationTime;
                } else {
                    durationSinceLastCalculation = getBlockTimestamp() - previousCalculationTime;
                }

                // Update new rewards period in the handler store.
                handlerStore.addRewardDistributionPeriod(poolId, durationSinceLastCalculation);
            }
        }

        // Update the timestamp for the last rewards period update.
        handlerStore.updateRewardsPeriodUpdatedAt(getBlockTimestamp());

        _;
    }

    /// @dev Records a function call for instrumentation purposes.
    modifier instrument(string memory functionName) {
        _;
        calls[selectedPoolId][functionName]++;
        totalCalls[functionName]++;
    }

    /// @dev Selects a pool ID from the store.
    modifier useFuzzedPool(uint256 poolIdIndex) {
        // Return if there are no pools.
        if (handlerStore.totalPools() == 0) {
            return;
        }

        poolIdIndex = bound(poolIdIndex, 0, handlerStore.totalPools() - 1);
        selectedPoolId = handlerStore.poolIds(poolIdIndex);
        _;
    }

    /// @dev Selects a staker from the store or creates a new one if there are no stakers.
    modifier useFuzzedStaker(uint256 stakerIndex) {
        uint256 totalStakers = handlerStore.totalStakers(selectedPoolId);

        // Create if there are no stakers.
        if (totalStakers == 0) {
            selectedStaker = vm.randomAddress();
            handlerStore.addStaker(selectedPoolId, selectedStaker);
        } else {
            stakerIndex = bound(stakerIndex, 0, totalStakers - 1);
            selectedStaker = handlerStore.poolStakers(selectedPoolId, stakerIndex);
        }
        setMsgSender(selectedStaker);
        _;
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
}
