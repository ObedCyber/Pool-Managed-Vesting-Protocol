// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface IAddressRegistry {
    function getLiquidityController() external view returns (address);

    function getTreasuryAddress() external view returns (address);

    function getVestingCoreAddress() external view returns (address);

    function getLiquidityManagerAddress() external view returns (address);

    function getVestedTokenAddress() external view returns (address);

    function getBaseTokenAddress() external view returns (address);
}
