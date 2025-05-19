// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ZERO } from "@prb/math/src/UD60x18.sol";
import { Errors as EvmUtilsErrors } from "@sablier/evm-utils/src/libraries/Errors.sol";
import { ERC20Mock } from "@sablier/evm-utils/src/mocks/erc20/ERC20Mock.sol";
import { BaseTest as EvmUtilsBase } from "@sablier/evm-utils/src/tests/BaseTest.sol";
import { LockupNFTDescriptor } from "@sablier/lockup/src/LockupNFTDescriptor.sol";
import { SablierLockup } from "@sablier/lockup/src/SablierLockup.sol";
import { Lockup, LockupLinear, Broker } from "@sablier/lockup/src/types/DataTypes.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";

import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";
import { SablierStaking } from "src/SablierStaking.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Modifiers } from "./utils/Modifiers.sol";
import { StreamIds, Users } from "./utils/Types.sol";

abstract contract Base_Test is Assertions, Modifiers {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    StreamIds internal ids;
    uint256 internal nullCampaignId = 420;
    ERC20Mock internal rewardToken;
    Users internal users;

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

        // Set the variables in Modifiers contract.
        setVariables(users);

        // Assign fee collector role to the accountant user.
        setMsgSender(users.admin);
        staking.grantRole(FEE_COLLECTOR_ROLE, users.accountant);

        // Create and configure Lockup streams for testing.
        createAndConfigureStreams();

        // Whitelist the Lockup contract for staking.
        setMsgSender(users.admin);
        ISablierLockupNFT[] memory lockups = new ISablierLockupNFT[](1);
        lockups[0] = lockup;
        staking.whitelistLockups(lockups);

        // Warp to Feb 1, 2025 at 00:00 UTC to provide a more realistic testing environment.
        vm.warp({ newTimestamp: FEB_1_2025 });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COMMON-REVERT-TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(EvmUtilsErrors.DelegateCall.selector), "delegatecall return data");
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(staking).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierStakingState_CampaignDoesNotExist.selector, nullCampaignId),
            "null call return data"
        );
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
        users.recipient = createUser("Recipient", spenders);
        users.sender = createUser("Sender", spenders);
        users.staker = createUser("Staker", spenders);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   LOCKUP-HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Creates the following Lockup streams:
    /// - A DAI stream that is cancelable.
    /// - A DAI stream that is not cancelable.
    /// - A USDC stream that is cancelable.
    function createAndConfigureStreams() internal {
        SablierLockup lockupContract = SablierLockup(address(lockup));

        // Allow the Lockup contract to hook with the staking contract.
        lockupContract.allowToHook(address(staking));

        // Change caller to the sender.
        setMsgSender(users.sender);

        (
            Lockup.CreateWithDurations memory params,
            LockupLinear.UnlockAmounts memory unlockAmounts,
            LockupLinear.Durations memory durations
        ) = defaultCreateWithDurationsLLParams(dai);

        // A DAI stream that is cancelable and will not be staked into the default campaign.
        ids.defaultStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A DAI stream that is cancelable and will be staked into the default campaign.
        ids.defaultStakedStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A DAI stream that is not cancelable and will be staked into the default campaign.
        (params, unlockAmounts, durations) = defaultCreateWithDurationsLLParams(dai);
        params.cancelable = false;
        ids.defaultStakedStreamNonCancelable = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A USDC stream that is cancelable.
        (params, unlockAmounts, durations) = defaultCreateWithDurationsLLParams(usdc);
        ids.differentTokenStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // Approve the staking contract to spend the Lockup NFTs.
        setMsgSender(users.recipient);
        lockupContract.setApprovalForAll({ operator: address(staking), approved: true });
    }

    /// @dev Returns the defaults parameters of the `createWithDurationsLL` function.
    function defaultCreateWithDurationsLLParams(ERC20 token)
        internal
        view
        returns (Lockup.CreateWithDurations memory, LockupLinear.UnlockAmounts memory, LockupLinear.Durations memory)
    {
        uint128 totalAmount = (STREAM_AMOUNT * 10 ** token.decimals()).toUint128();

        return (
            Lockup.CreateWithDurations({
                sender: users.sender,
                recipient: users.recipient,
                totalAmount: totalAmount,
                token: token,
                cancelable: true,
                transferable: true,
                shape: "linear",
                broker: Broker({ account: address(0), fee: ZERO })
            }),
            LockupLinear.UnlockAmounts({ start: 0, cliff: 0 }),
            LockupLinear.Durations({ cliff: 0, total: STREAM_DURATION })
        );
    }
}
