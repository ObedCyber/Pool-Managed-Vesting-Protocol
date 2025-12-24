// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface ILiquidityManager {
    function getPositionLiquidity() external view returns (uint128);
}
