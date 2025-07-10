// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ISablierComptroller } from "@sablier/evm-utils/src/interfaces/ISablierComptroller.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract CalculateMinFeeWeiFor_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_Null() external {
        bytes memory callData = abi.encodeCall(sablierStaking.calculateMinFeeWei, (poolIds.nullPool));
        expectRevert_Null(callData);
    }

    function test_RevertGiven_Closed() external whenNotNull {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierStakingState_PoolClosed.selector, poolIds.closedPool));
        sablierStaking.calculateMinFeeWei(poolIds.closedPool);
    }

    function test_GivenCustomFeeSet() external whenNotNull givenNotClosed {
        setMsgSender(admin);

        uint256 customFeeUSD = 100e8; // 100 USD.

        // Set the custom fee.
        comptroller.setCustomFeeUSDFor({
            protocol: ISablierComptroller.Protocol.Staking,
            user: sablierStaking.getAdmin(poolIds.defaultPool),
            customFeeUSD: customFeeUSD
        });

        uint256 expectedFeeWei = (1e18 * customFeeUSD) / ETH_PRICE_USD;

        // It should return the custom fee in wei.
        assertEq(sablierStaking.calculateMinFeeWei(poolIds.defaultPool), expectedFeeWei, "customFeeWei");
    }

    function test_GivenCustomFeeNotSet() external view whenNotNull givenNotClosed {
        // It should return the minimum fee in wei.
        assertEq(sablierStaking.calculateMinFeeWei(poolIds.defaultPool), STAKING_MIN_FEE_WEI, "minFeeWei");
    }
}
