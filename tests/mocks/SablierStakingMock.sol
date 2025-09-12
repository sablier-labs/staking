// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { SablierStaking } from "src/SablierStaking.sol";

/// @dev Since `_snapshotRewards` function contains core logic, this mock contract exposes it publicly, and allows us to
/// test it separately.
contract SablierStakingMock is SablierStaking {
    constructor(address initialComptroller) SablierStaking(initialComptroller) { }

    function snapshotRewards(uint256 poolId, address user) external {
        _snapshotRewards(poolId, user);
    }
}
