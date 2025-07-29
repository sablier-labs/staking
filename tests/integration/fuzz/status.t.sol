// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { Status } from "src/types/DataTypes.sol";
import { Shared_Integration_Fuzz_Test } from "./Fuzz.t.sol";

contract Status_Integration_Fuzz_Test is Shared_Integration_Fuzz_Test {
    function testFuzz_Status_SCHEDULED(uint40 timestamp) external whenNotNull {
        // Bound timestamp so that it is less than the start time.
        vm.assume(timestamp < START_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        Status actualStatus = sablierStaking.status(poolIds.defaultPool);
        Status expectedStatus = Status.SCHEDULED;
        assertEq(actualStatus, expectedStatus, "status");
    }

    function testFuzz_Status_ACTIVE(uint40 timestamp) external whenNotNull {
        // Bound timestamp so that it is between the start and end times.
        timestamp = boundUint40(timestamp, START_TIME, END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        Status actualStatus = sablierStaking.status(poolIds.defaultPool);
        Status expectedStatus = Status.ACTIVE;
        assertEq(actualStatus, expectedStatus, "status");
    }

    function testFuzz_Status_ENDED(uint40 timestamp) external whenNotNull {
        // Bound timestamp so that it is greater than the end time.
        vm.assume(timestamp > END_TIME);

        // Warp the EVM state to the given timestamp.
        warpStateTo(timestamp);

        Status actualStatus = sablierStaking.status(poolIds.defaultPool);
        Status expectedStatus = Status.ENDED;
        assertEq(actualStatus, expectedStatus, "status");
    }
}
