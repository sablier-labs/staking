// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ISablierStaking } from "src/interfaces/ISablierStaking.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract UnstakeLockupNFT_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(sablierStaking.unstakeLockupNFT, (lockup, streamIds.defaultStakedStream));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_NoStakedNFT() external whenNoDelegateCall {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierStaking_StreamNotStaked.selector, lockup, streamIds.defaultStream)
        );
        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStream);
    }

    function test_GivenClosed() external whenNoDelegateCall givenStakedNFT {
        // Setup a state where the pool is closed after the Lockup stream is staked.
        warpStateTo(START_TIME - 1);
        sablierStaking.stakeLockupNFT(poolIds.defaultPool, lockup, streamIds.defaultStakedStream);

        // Close the pool.
        setMsgSender(users.poolCreator);
        sablierStaking.closePool(poolIds.defaultPool);

        // Change the caller to the recipient.
        setMsgSender(users.recipient);

        // It should emit {Transfer} and {UnstakeLockupNFT} events.
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(address(sablierStaking), users.recipient, streamIds.defaultStakedStream);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeLockupNFT(
            poolIds.defaultPool, users.recipient, lockup, streamIds.defaultStakedStream
        );

        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);

        // It should unstake NFT.
        (uint128 actualStreamsCount, uint128 actualStreamAmountStaked,) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(actualStreamsCount, 0, "streamsCount");
        assertEq(actualStreamAmountStaked, 0, "streamAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(globalLastUpdateTime, START_TIME - 1, "globalLastUpdateTime");
        assertEq(rewardsDistributedPerTokenScaled, 0, "rewardsDistributedPerTokenScaled");

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);
        assertEq(userLastUpdateTime, START_TIME - 1, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, 0, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, 0, "rewards");
    }

    function test_RevertWhen_CallerNotNFTOwner() external whenNoDelegateCall givenStakedNFT givenNotClosed {
        setMsgSender(users.eve);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierStaking_CallerNotStreamOwner.selector,
                lockup,
                streamIds.defaultStakedStream,
                users.eve,
                users.recipient
            )
        );
        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);
    }

    function test_WhenCallerNFTOwner() external whenNoDelegateCall givenStakedNFT givenNotClosed {
        // It should emit {SnapshotRewards}, {Transfer} and {UnstakeERC20Token} events.
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.SnapshotRewards(
            poolIds.defaultPool,
            WARP_40_PERCENT,
            REWARDS_DISTRIBUTED_PER_TOKEN_SCALED,
            users.recipient,
            REWARDS_EARNED_BY_RECIPIENT
        );
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC721.Transfer(address(sablierStaking), users.recipient, streamIds.defaultStakedStream);
        vm.expectEmit({ emitter: address(sablierStaking) });
        emit ISablierStaking.UnstakeLockupNFT(
            poolIds.defaultPool, users.recipient, lockup, streamIds.defaultStakedStream
        );

        sablierStaking.unstakeLockupNFT(lockup, streamIds.defaultStakedStream);

        // It should unstake NFT.
        (uint128 actualStreamsCount, uint128 actualStreamAmountStaked,) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(actualStreamsCount, 1, "streamsCount");
        assertEq(actualStreamAmountStaked, STREAM_AMOUNT_18D, "streamAmountStakedByUser");

        // It should update global rewards snapshot.
        (uint40 globalLastUpdateTime, uint256 rewardsDistributedPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(globalLastUpdateTime, WARP_40_PERCENT, "globalLastUpdateTime");
        assertEq(
            rewardsDistributedPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (uint40 userLastUpdateTime, uint256 rewardsEarnedPerTokenScaled, uint128 rewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);
        assertEq(userLastUpdateTime, WARP_40_PERCENT, "userLastUpdateTime");
        assertEq(rewardsEarnedPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsEarnedPerTokenScaled");
        assertEq(rewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
