// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

abstract contract Constants {
    // Campaign
    uint40 internal constant END_TIME = TWELVE_MONTHS_SINCE_CREATE;
    uint128 internal constant REWARDS_DISTRIBUTED_PER_TOKEN = TOTAL_REWARDS_AMOUNT / TOTAL_STAKED_AMOUNT;
    uint40 internal constant START_TIME = ONE_MONTH_SINCE_CREATE;
    uint128 internal constant TOTAL_REWARDS_AMOUNT = 1_000_000e18; // Fixed 1M rewards

    // Lockup
    uint40 internal constant STREAM_DURATION = TWELVE_MONTHS;
    uint128 internal constant TOTAL_STREAM_AMOUNT = 10_000; // equivalent to 10_000 * 10^TOKEN_DECIMALS
    uint128 internal constant TOTAL_STREAM_AMOUNT_18D = 10_000e18;

    // Staked Amounts
    uint128 internal constant STAKED_ERC20_AMOUNT = 10_000e18;
    uint128 internal constant STAKED_LOCKUP_AMOUNT = TOTAL_STREAM_AMOUNT_18D;
    uint256 internal constant STAKED_STREAM_COUNT = 1;
    uint128 internal constant TOTAL_STAKED_AMOUNT = STAKED_ERC20_AMOUNT + STAKED_LOCKUP_AMOUNT;

    // Misc
    uint40 internal constant FEB_1_2025 = 1_738_368_000;
    uint40 internal constant ONE_MONTH = 30 days; // "30/360" convention
    uint40 internal constant ONE_MONTH_SINCE_CREATE = FEB_1_2025 + ONE_MONTH;
    uint40 internal constant TWELVE_MONTHS = 360 days;
    uint40 internal constant TWELVE_MONTHS_SINCE_CREATE = FEB_1_2025 + TWELVE_MONTHS;
}
