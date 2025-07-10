// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.26;

import { BaseConstants } from "@sablier/evm-utils/src/tests/BaseConstants.sol";

abstract contract Constants is BaseConstants {
    // Pool Parameters
    uint40 internal constant END_TIME = START_TIME + REWARD_PERIOD;
    uint128 internal constant REWARD_AMOUNT = 10_000_000e18; // Fixed 10M rewards
    uint40 internal constant REWARD_PERIOD = ONE_MONTH * 10; // 10 months = 300 days
    uint128 internal constant REWARD_RATE = 0.385802469135802469e18; // 10M / 300 days
    uint40 internal constant START_TIME = ONE_MONTH_SINCE_CREATE;

    // Lockup Stream
    // Streams will have their end time before rewards end time because streams are created at `FEB_1_2025` whereas
    // rewards start at `FEB_1_2025 + 1 month`.
    uint40 internal constant STREAM_DURATION = ONE_MONTH * 10; // 10 months.
    uint128 internal constant STREAM_AMOUNT = 10_000; // equivalent to DEFAULT_STAKED_AMOUNT in 18 decimals
    uint128 internal constant STREAM_AMOUNT_18D = 10_000e18;

    // Miscellaneous
    uint40 internal constant FEB_1_2025 = 1_738_368_000;
    uint128 internal constant DEFAULT_AMOUNT = 10_000e18;
    uint128 internal constant MAX_AMOUNT_STAKED = AMOUNT_STAKED_BY_RECIPIENT_END_TIME + AMOUNT_STAKED_BY_STAKER_END_TIME;
    uint40 internal constant ONE_MONTH = 30 days; // "30/360" convention
    uint40 internal constant ONE_MONTH_SINCE_CREATE = FEB_1_2025 + ONE_MONTH;
    uint256 internal constant SCALE_FACTOR = 1e20;

    // Pre rewards start
    uint128 internal constant AMOUNT_STAKED_BY_RECIPIENT_PRE_START = 0;
    uint128 internal constant AMOUNT_STAKED_BY_STAKER_PRE_START = 10_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_RECIPIENT_PRE_START = 0;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_STAKER_PRE_START = 10_000e18;
    uint8 internal constant STREAMS_COUNT_FOR_RECIPIENT_PRE_START = 0;
    uint128 internal constant TOTAL_STAKED_PRE_START = 10_000e18;

    // 0% through the rewards period
    uint128 internal constant AMOUNT_STAKED_BY_RECIPIENT_START_TIME = 10_000e18;
    uint128 internal constant AMOUNT_STAKED_BY_STAKER_START_TIME = 10_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_RECIPIENT_START_TIME = 0;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_STAKER_START_TIME = 10_000e18;
    uint8 internal constant STREAMS_COUNT_FOR_RECIPIENT_START_TIME = 1;
    uint128 internal constant TOTAL_STAKED_START_TIME =
        AMOUNT_STAKED_BY_RECIPIENT_START_TIME + AMOUNT_STAKED_BY_STAKER_START_TIME;

    // 20% through the rewards period
    uint128 internal constant AMOUNT_STAKED_BY_RECIPIENT_20_PERCENT = 30_000e18;
    uint128 internal constant AMOUNT_STAKED_BY_STAKER_20_PERCENT = 10_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_RECIPIENT_20_PERCENT = 10_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_STAKER_20_PERCENT = 10_000e18;
    uint128 internal constant REWARDS_DISTRIBUTED_20_PERCENT = 2_000_000e18; // 2M tokens
    uint128 internal constant REWARDS_DISTRIBUTED_PER_TOKEN_20_PERCENT = 100; // 2M / 20k
    uint128 internal constant REWARDS_EARNED_BY_RECIPIENT_20_PERCENT = 1_000_000e18;
    uint128 internal constant REWARDS_EARNED_BY_STAKER_20_PERCENT = 1_000_000e18;
    uint8 internal constant STREAMS_COUNT_FOR_RECIPIENT_20_PERCENT = 2;
    uint128 internal constant TOTAL_STAKED_20_PERCENT =
        AMOUNT_STAKED_BY_RECIPIENT_20_PERCENT + AMOUNT_STAKED_BY_STAKER_20_PERCENT;
    uint40 internal constant WARP_20_PERCENT = START_TIME + 60 days;

    // 40% through the rewards period (time at which most integration tests are performed)
    uint128 internal constant AMOUNT_STAKED_BY_RECIPIENT = 30_000e18;
    uint128 internal constant AMOUNT_STAKED_BY_STAKER = 20_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_RECIPIENT = 10_000e18;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_STAKER = 20_000e18;
    uint128 internal constant REWARDS_DISTRIBUTED = 4_000_000e18; // 4M tokens
    uint128 internal constant REWARDS_DISTRIBUTED_PER_TOKEN = 150; // 100 + 2M / 40k
    uint256 internal constant REWARDS_DISTRIBUTED_PER_TOKEN_SCALED = REWARDS_DISTRIBUTED_PER_TOKEN * SCALE_FACTOR;
    uint128 internal constant REWARDS_EARNED_BY_RECIPIENT = REWARDS_EARNED_BY_RECIPIENT_20_PERCENT + 1_500_000e18;
    uint128 internal constant REWARDS_EARNED_BY_STAKER = REWARDS_EARNED_BY_STAKER_20_PERCENT + 500_000e18;
    uint128 internal constant TOTAL_STAKED = AMOUNT_STAKED_BY_RECIPIENT + AMOUNT_STAKED_BY_STAKER;
    uint40 internal constant WARP_40_PERCENT = START_TIME + 120 days;

    // 100% through the rewards period
    uint128 internal constant AMOUNT_STAKED_BY_RECIPIENT_END_TIME = AMOUNT_STAKED_BY_RECIPIENT;
    uint128 internal constant AMOUNT_STAKED_BY_STAKER_END_TIME = AMOUNT_STAKED_BY_STAKER;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_RECIPIENT_END_TIME = DIRECT_AMOUNT_STAKED_BY_RECIPIENT;
    uint128 internal constant DIRECT_AMOUNT_STAKED_BY_STAKER_END_TIME = DIRECT_AMOUNT_STAKED_BY_STAKER;
    uint128 internal constant REWARDS_DISTRIBUTED_END_TIME = 10_000_000e18; // 10M tokens
    uint128 internal constant REWARDS_DISTRIBUTED_PER_TOKEN_END_TIME = 270; // 150 + 6M / 50k
    uint128 internal constant REWARDS_EARNED_BY_RECIPIENT_END_TIME = REWARDS_EARNED_BY_RECIPIENT + 3_600_000e18;
    uint128 internal constant REWARDS_EARNED_BY_STAKER_END_TIME = REWARDS_EARNED_BY_STAKER + 2_400_000e18;
    uint8 internal constant STREAMS_COUNT_FOR_RECIPIENT_END_TIME = 2;
    uint128 internal constant TOTAL_STAKED_END_TIME = AMOUNT_STAKED_BY_RECIPIENT + AMOUNT_STAKED_BY_STAKER;
}
