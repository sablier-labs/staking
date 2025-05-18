// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20Mock } from "@sablier/evm-utils/src/mocks/erc20/ERC20Mock.sol";
import { BaseTest as EvmUtilsBase } from "@sablier/evm-utils/src/tests/BaseTest.sol";
import { LockupNFTDescriptor } from "@sablier/lockup/src/LockupNFTDescriptor.sol";
import { SablierLockup } from "@sablier/lockup/src/SablierLockup.sol";

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { SablierStaking } from "src/SablierStaking.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Modifiers } from "./utils/Modifiers.sol";
import { StreamIds, Users } from "./utils/Types.sol";

abstract contract Base_Test is Assertions, Modifiers {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    StreamIds internal ids;

    // The following token is used for distributing rewards.
    ERC20Mock internal rewardToken;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISablierLockupNFT internal lockup;
    ISablierStaking internal staking;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        EvmUtilsBase.setUp();

        // Deploy the reward token for distributing rewards.
        rewardToken = new ERC20Mock("Reward Token", "REWARD_TOKEN", 18);
        tokens.push(rewardToken);

        users.admin = payable(makeAddr("admin"));

        // Deploy the staking protocol.
        if (!isTestOptimizedProfile()) {
            staking = new SablierStaking(users.admin);
        } else {
            staking = deployOptimizedSablierStaking(users.admin);
        }

        // Deploy the Lockup contract for testing.
        LockupNFTDescriptor nftDescriptor = new LockupNFTDescriptor();
        lockup = ISablierLockupNFT(address(new SablierLockup(users.admin, nftDescriptor, 1000)));

        // Label the contracts.
        vm.label({ account: address(lockup), newLabel: "Lockup" });
        vm.label({ account: address(rewardToken), newLabel: "Reward Token" });
        vm.label({ account: address(staking), newLabel: "Staking Protocol" });

        // Create users for testing.
        createTestUsers();

        // Assign fee collector role to the accountant user.
        setMsgSender(users.admin);
        staking.grantRole(FEE_COLLECTOR_ROLE, users.accountant);

        // Warp to Feb 1, 2025 at 00:00 UTC to provide a more realistic testing environment.
        vm.warp({ newTimestamp: FEB_1_2025 });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Create users for testing and assign roles if applicable.
    function createTestUsers() internal {
        // Create users for testing.
        address[] memory spenders = new address[](2);
        spenders[0] = address(staking);
        spenders[1] = address(lockup);

        // Create test users and approve the staking contract to spend their ERC20 tokens.
        users.accountant = createUser("Accountant", spenders);
        users.campaignCreator = createUser("Campaign Creator", spenders);
        users.eve = createUser("eve", spenders);
        users.sender = createUser("Sender", spenders);
        users.staker = createUser("Staker", spenders);
    }
}
