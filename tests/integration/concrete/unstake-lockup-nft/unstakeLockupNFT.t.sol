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

    function test_RevertWhen_CallerNotNFTOwner() external whenNoDelegateCall givenStakedNFT {
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

    function test_WhenCallerNFTOwner() external whenNoDelegateCall givenStakedNFT {
        vars.expectedTotalAmountStaked = sablierStaking.totalAmountStaked(poolIds.defaultPool) - DEFAULT_AMOUNT;

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
        (vars.actualStreamCount, vars.actualStreamAmountStaked,) =
            sablierStaking.userShares(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualStreamCount, 1, "streamsCount");
        assertEq(vars.actualStreamAmountStaked, STREAM_AMOUNT_18D, "streamAmountStakedByUser");

        // It should decrease total amount staked.
        vars.actualTotalAmountStaked = sablierStaking.totalAmountStaked(poolIds.defaultPool);
        assertEq(vars.actualTotalAmountStaked, vars.expectedTotalAmountStaked, "total amount staked");

        // It should update global rewards snapshot.
        (vars.actualLastUpdateTime, vars.actualRewardsPerTokenScaled) =
            sablierStaking.globalSnapshot(poolIds.defaultPool);
        assertEq(vars.actualLastUpdateTime, WARP_40_PERCENT, "globalLastUpdateTime");
        assertEq(
            vars.actualRewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsDistributedPerTokenScaled"
        );

        // It should update user rewards snapshot.
        (vars.actualLastUpdateTime, vars.actualRewardsPerTokenScaled, vars.actualUserRewards) =
            sablierStaking.userSnapshot(poolIds.defaultPool, users.recipient);
        assertEq(vars.actualLastUpdateTime, WARP_40_PERCENT, "userLastUpdateTime");
        assertEq(vars.actualRewardsPerTokenScaled, REWARDS_DISTRIBUTED_PER_TOKEN_SCALED, "rewardsEarnedPerTokenScaled");
        assertEq(vars.actualUserRewards, REWARDS_EARNED_BY_RECIPIENT, "rewards");
    }
}
