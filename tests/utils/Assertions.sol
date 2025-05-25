// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StdAssertions } from "forge-std/src/StdAssertions.sol";

import { StakingCampaign } from "../../src/types/DataTypes.sol";

abstract contract Assertions is StdAssertions {
    /*//////////////////////////////////////////////////////////////////////////
                                     ASSERTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b) internal pure {
        assertEq(address(a), address(b));
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b, string memory err) internal pure {
        assertEq(address(a), address(b), err);
    }

    /// @dev Compares two {StakingCampaign} struct entities.
    function assertEq(StakingCampaign memory a, StakingCampaign memory b) internal pure {
        assertEq(a.admin, b.admin, "admin");
        assertEq(a.rewardToken, b.rewardToken, "rewardToken");
        assertEq(a.stakingToken, b.stakingToken, "stakingToken");
        assertEq(a.wasCanceled, b.wasCanceled, "wasCanceled");
        assertEq(a.endTime, b.endTime, "endTime");
        assertEq(a.startTime, b.startTime, "startTime");
        assertEq(a.totalRewards, b.totalRewards, "totalRewards");
    }
}
