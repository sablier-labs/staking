// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

contract LockupWithoutGetAssetOrGetUnderlyingToken {
    function getDepositedAmount(uint256 streamId) external view returns (uint128) { }
    function getRefundedAmount(uint256 streamId) external view returns (uint128) { }
    function getWithdrawnAmount(uint256 streamId) external view returns (uint128) { }
}

contract LockupWithoutGetDepositedAmount {
    function getRefundedAmount(uint256 streamId) external view returns (uint128) { }
    function getUnderlyingToken(uint256 streamId) external view returns (address) { }
    function getWithdrawnAmount(uint256 streamId) external view returns (uint128) { }
}

contract LockupWithoutGetRefundedAmount {
    function getDepositedAmount(uint256 streamId) external view returns (uint128) { }
    function getUnderlyingToken(uint256 streamId) external view returns (address) { }
    function getWithdrawnAmount(uint256 streamId) external view returns (uint128) { }
}

contract LockupWithoutGetWithdrawnAmount {
    function getDepositedAmount(uint256 streamId) external view returns (uint128) { }
    function getRefundedAmount(uint256 streamId) external view returns (uint128) { }
    function getUnderlyingToken(uint256 streamId) external view returns (address) { }
}
