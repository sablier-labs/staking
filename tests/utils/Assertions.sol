// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StdAssertions } from "forge-std/src/StdAssertions.sol";
import { Status } from "src/types/DataTypes.sol";

abstract contract Assertions is StdAssertions {
    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b, string memory err) internal pure {
        assertEq(address(a), address(b), err);
    }

    /// @dev Compares two {Status} values.
    function assertEq(Status a, Status b, string memory err) internal pure {
        assertEq(uint256(a), uint256(b), err);
    }
}
