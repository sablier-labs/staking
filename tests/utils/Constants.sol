// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

abstract contract Constants {
    // Amounts
    uint128 internal constant TOTAL_STREAM_AMOUNT = 10_000; // equivalent to 10_000 * 10^TOKEN_DECIMALS

    // Timestamps
    uint40 internal constant FEB_1_2025 = 1_738_368_000;
    uint40 internal constant ONE_MONTH = 30 days; // "30/360" convention
    uint40 internal constant ONE_MONTH_SINCE_CREATE = FEB_1_2025 + ONE_MONTH;
    uint40 internal constant TWELVE_MONTHS = 360 days;
    uint40 internal constant TWELVE_MONTHS_SINCE_CREATE = FEB_1_2025 + TWELVE_MONTHS;
}
