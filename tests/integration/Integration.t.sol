// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ZERO } from "@prb/math/src/UD60x18.sol";
import { SablierLockup } from "@sablier/lockup/src/SablierLockup.sol";
import { Lockup, LockupLinear, Broker } from "@sablier/lockup/src/types/DataTypes.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";
import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                       SET-UP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Create and configure Lockup streams for testing.
        createAndConfigureStreams();

        // Whitelist the Lockup contract for staking.
        setMsgSender(users.admin);
        ISablierLockupNFT[] memory lockups = new ISablierLockupNFT[](1);
        lockups[0] = lockup;
        staking.whitelistLockups(lockups);

        // Set the variables in Modifiers contract.
        setVariables(users);

        // Set campaign creator as the default caller.
        setMsgSender(users.campaignCreator);
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

        // A DAI stream that is cancelable and will be staked into the default campaign.
        ids.defaultStakedStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A DAI stream that is cancelable and will not be staked into the default campaign.
        ids.defaultUnstakedStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A USDC stream that is cancelable.
        (params, unlockAmounts, durations) = defaultCreateWithDurationsLLParams(usdc);
        ids.differentTokenStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // A DAI stream that is not cancelable.
        (params, unlockAmounts, durations) = defaultCreateWithDurationsLLParams(dai);
        params.cancelable = false;
        ids.notCancelableStream = lockupContract.createWithDurationsLL(params, unlockAmounts, durations);

        // Approve the staking contract to spend the Lockup NFTs.
        setMsgSender(users.staker);
        lockupContract.setApprovalForAll({ operator: address(staking), approved: true });
    }

    /// @dev Returns the defaults parameters of the `createWithDurationsLL` function.
    function defaultCreateWithDurationsLLParams(ERC20 token)
        internal
        view
        returns (Lockup.CreateWithDurations memory, LockupLinear.UnlockAmounts memory, LockupLinear.Durations memory)
    {
        uint128 totalAmount = (TOTAL_STREAM_AMOUNT * 10 ** token.decimals()).toUint128();

        return (
            Lockup.CreateWithDurations({
                sender: users.sender,
                recipient: users.staker,
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
