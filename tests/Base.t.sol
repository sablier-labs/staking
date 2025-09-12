// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ZERO } from "@prb/math/src/UD60x18.sol";
import { ISablierComptroller } from "@sablier/evm-utils/src/interfaces/ISablierComptroller.sol";
import { ERC20Mock } from "@sablier/evm-utils/src/mocks/erc20/ERC20Mock.sol";
import { BaseTest as EvmUtilsBase } from "@sablier/evm-utils/src/tests/BaseTest.sol";
import { LockupNFTDescriptor } from "@sablier/lockup/src/LockupNFTDescriptor.sol";
import { SablierLockup } from "@sablier/lockup/src/SablierLockup.sol";
import { Lockup, LockupLinear, Broker } from "@sablier/lockup/src/types/DataTypes.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";
import { ISablierLockupNFT } from "src/interfaces/ISablierLockupNFT.sol";

import { SablierStakingMock } from "./mocks/SablierStakingMock.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Modifiers } from "./utils/Modifiers.sol";
import { StreamIds, Users } from "./utils/Types.sol";
import { Utils } from "./utils/Utils.sol";

abstract contract Base_Test is Assertions, Modifiers, Utils {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    ERC20Mock internal rewardToken;
    ERC20Mock internal stakingToken;
    StreamIds internal streamIds;
    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISablierLockupNFT internal lockup;

    /// @dev Since `_snapshotRewards` function contains core logic, a mock contract is used to allow testing it
    /// separately.
    SablierStakingMock internal sablierStaking;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        EvmUtilsBase.setUp();

        // Deploy the reward token.
        rewardToken = new ERC20Mock("Reward Token", "REWARD_TOKEN", 18);
        tokens.push(rewardToken);

        // Deploy the staking token.
        stakingToken = new ERC20Mock("Staking Token", "STAKING_TOKEN", 18);
        tokens.push(stakingToken);

        // Deploy the staking protocol.
        if (!isTestOptimizedProfile()) {
            sablierStaking = new SablierStakingMock(address(comptroller));
        } else {
            sablierStaking = deployOptimizedSablierStaking(address(comptroller));
        }

        // Deploy the Lockup contract for testing.
        lockup = deployLockup();

        // Label the contracts.
        vm.label({ account: address(lockup), newLabel: "Lockup" });
        vm.label({ account: address(rewardToken), newLabel: "Reward Token" });
        vm.label({ account: address(sablierStaking), newLabel: "Staking Protocol" });

        // Create users for testing.
        createTestUsers();

        // Set the variables in Modifiers contract.
        setVariables(users);

        // Warp to Feb 1, 2025 at 00:00 UTC to provide a more realistic testing environment.
        vm.warp({ newTimestamp: FEB_1_2025 });

        // Create and configure Lockup streams for testing.
        createAndConfigureStreams();

        // Set the minimum fee for the staking protocol.
        setMsgSender(admin);
        comptroller.setMinFeeUSD(ISablierComptroller.Protocol.Staking, STAKING_MIN_FEE_USD);

        // Whitelist the Lockup contract for staking.
        setMsgSender(address(comptroller));
        ISablierLockupNFT[] memory lockups = new ISablierLockupNFT[](1);
        lockups[0] = lockup;
        sablierStaking.whitelistLockups(lockups);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Create users for testing and assign roles if applicable.
    function createTestUsers() internal {
        // Create users for testing.
        address[] memory spenders = new address[](2);
        spenders[0] = address(sablierStaking);
        spenders[1] = address(lockup);

        // Create test users and approve the staking pool to spend their ERC20 tokens.
        users.eve = createUser("eve", spenders);
        users.poolCreator = createUser("Pool Creator", spenders);
        users.recipient = createUser("Recipient", spenders);
        users.sender = createUser("Sender", spenders);
        users.staker = createUser("Staker", spenders);
    }

    /// @dev Deploys {SablierStakingMock} from an optimized source compiled with `--via-ir`.
    function deployOptimizedSablierStaking(address admin) internal returns (SablierStakingMock) {
        return SablierStakingMock(
            deployCode("out-optimized/SablierStakingMock.sol/SablierStakingMock.json", abi.encode(admin))
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   LOCKUP-HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Returns the amount available in the given stream.
    function amountInStream(uint256 streamId) private view returns (uint128 amount) {
        return lockup.getDepositedAmount(streamId) - lockup.getWithdrawnAmount(streamId)
            - lockup.getRefundedAmount(streamId);
    }

    /// @dev Creates the following Lockup streams:
    /// - A stream with staking token that is cancelable.
    /// - A stream with staking token that is not cancelable.
    /// - A stream with USDC that is cancelable.
    function createAndConfigureStreams() internal {
        SablierLockup lockupContract = SablierLockup(address(lockup));

        // Allow the Lockup contract to hook with the staking pool.
        setMsgSender(address(comptroller));
        lockupContract.allowToHook(address(sablierStaking));

        // Change caller to the sender.
        setMsgSender(users.sender);

        // A stream that is cancelable and will not be staked into the default pool.
        streamIds.defaultStream = defaultCreateWithDurationsLL();

        // A stream that is cancelable and will be staked into the default pool.
        streamIds.defaultStakedStream = defaultCreateWithDurationsLL();

        // A stream that is not cancelable and will be staked into the default pool.
        streamIds.defaultStakedStreamNonCancelable = defaultCreateWithDurationsLL({ cancelable: false });

        // A USDC stream that is cancelable.
        streamIds.differentTokenStream = defaultCreateWithDurationsLL(usdc);

        // Approve the staking pool to spend the Lockup NFTs.
        setMsgSender(users.recipient);
        lockupContract.setApprovalForAll({ operator: address(sablierStaking), approved: true });
    }

    /// @dev Create a stream with `createWithDurationsLL` function using the default parameters.
    function defaultCreateWithDurationsLL() internal returns (uint256 streamId) {
        return defaultCreateWithDurationsLL(true, users.recipient, stakingToken);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with cancelable parameter.
    function defaultCreateWithDurationsLL(bool cancelable) internal returns (uint256 streamId) {
        return defaultCreateWithDurationsLL(cancelable, users.recipient, stakingToken);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with recipient parameter.
    function defaultCreateWithDurationsLL(address recipient) internal returns (uint256 streamId) {
        return defaultCreateWithDurationsLL(true, recipient, stakingToken);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with token parameter.
    function defaultCreateWithDurationsLL(ERC20 token) internal returns (uint256 streamId) {
        return defaultCreateWithDurationsLL(true, users.recipient, token);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with amount and recipient.
    function defaultCreateWithDurationsLL(uint128 amount, address recipient) internal returns (uint256 streamId) {
        return defaultCreateWithDurationsLL(amount, true, recipient, stakingToken);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with cancelable, recipient and token parameters.
    function defaultCreateWithDurationsLL(
        bool cancelable,
        address recipient,
        ERC20 token
    )
        internal
        returns (uint256 streamId)
    {
        uint128 totalAmount = (STREAM_AMOUNT * 10 ** token.decimals()).toUint128();

        return defaultCreateWithDurationsLL(totalAmount, cancelable, recipient, token);
    }

    /// @dev Create a stream with `createWithDurationsLL` function with amount, cancelable, recipient and token
    /// parameters.
    function defaultCreateWithDurationsLL(
        uint128 amount,
        bool cancelable,
        address recipient,
        ERC20 token
    )
        internal
        returns (uint256 streamId)
    {
        deal({ token: address(stakingToken), to: users.sender, give: amount });
        setMsgSender(users.sender);
        stakingToken.approve(address(lockup), amount);

        Lockup.CreateWithDurations memory params = Lockup.CreateWithDurations({
            sender: users.sender,
            recipient: recipient,
            totalAmount: amount,
            token: token,
            cancelable: cancelable,
            transferable: true,
            shape: "linear",
            broker: Broker({ account: address(0), fee: ZERO })
        });
        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({ start: 0, cliff: 0 });
        LockupLinear.Durations memory durations = LockupLinear.Durations({ cliff: 0, total: STREAM_DURATION });

        return SablierLockup(address(lockup)).createWithDurationsLL(params, unlockAmounts, durations);
    }

    /// @dev Deploys a new Lockup contract for testing.
    function deployLockup() internal returns (ISablierLockupNFT) {
        LockupNFTDescriptor nftDescriptor = new LockupNFTDescriptor();
        return ISablierLockupNFT(address(new SablierLockup(address(comptroller), nftDescriptor, 1000)));
    }
}
