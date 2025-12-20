// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAddressRegistry} from "../interfaces/IAddressRegistry.sol";
import {ILiquidityManager} from "../interfaces/ILiquidityManager.sol";
import {IVestingCore} from "../interfaces/IVestingCore.sol";

contract Treasury {
    IERC20 public vestedtoken; //$VEST
    IERC20 public baseToken; // $USDC
    IAddressRegistry public registry;

    uint256 public minReserveBps = 500; // 5% minimum reserve
    uint256 public constant BPS_DENOMINATOR = 10000;
    bool public emergencyMode;

    error Treasury__NotAuthorized();
    error Treasury__EmergencyModeActive();
    error Treasury__ReserveBreached();
    error Treasury__InvalidInputs();

    event TokensPulled(
        address indexed to,
        uint256 amountVested,
        uint256 amountBase
    );

    constructor(address _registry) {
        registry = IAddressRegistry(_registry);
        vestedtoken = IERC20(registry.getVestedTokenAddress());
        baseToken = IERC20(registry.getBaseTokenAddress());
    }

    modifier onlyAuthorized() {
        if (
            msg.sender != registry.getLiquidityManagerAddress() &&
            msg.sender != registry.getVestingCoreAddress()
        ) {
            revert Treasury__NotAuthorized();
        }
        _;
    }

    function setEmergencyMode(bool _emergencyMode) external onlyAuthorized {
        emergencyMode = _emergencyMode;
    }

    ///@notice Pull tokens from the treasury
    function pullTokens(
        uint256 amountVested,
        uint256 amountBase
    ) external onlyAuthorized {
        (uint256 vestedBalance, uint256 baseBalance) = getBalanceAfterTransfer(
            amountVested,
            amountBase
        );
        (
            uint256 minVestedReserve,
            uint256 minBaseReserve
        ) = getMinimumReserveReq();
        if (vestedBalance < minVestedReserve || baseBalance < minBaseReserve) {
            revert Treasury__ReserveBreached();
        }
        if(amountBase == 0 && amountVested == 0) {
            revert Treasury__InvalidInputs();
        }
        // emergency mode blocks more token from being pulled by the liquidity manager
        if (emergencyMode && msg.sender == registry.getLiquidityManagerAddress()) {
            revert Treasury__EmergencyModeActive();
        }

        if (amountVested > 0) vestedtoken.transfer(msg.sender, amountVested);
        if (amountBase > 0) baseToken.transfer(msg.sender, amountBase);


        emit TokensPulled(msg.sender, amountVested, amountBase);
    }

    ///@notice calculate the minimum reserve required
    function getMinimumReserveReq() internal view returns (uint256, uint256) {
        uint256 totalVestedTokens = vestedtoken.balanceOf(address(this));
        uint256 totalBaseTokens = baseToken.balanceOf(address(this));
        uint256 minVestedReserve = (totalVestedTokens * minReserveBps) /
            BPS_DENOMINATOR;
        uint256 minBaseReserve = (totalBaseTokens * minReserveBps) /
            BPS_DENOMINATOR;
        return (minVestedReserve, minBaseReserve);
    }

    ///@notice get balances after accounting for the transfer amounts
    function getBalanceAfterTransfer(
        uint256 amountVested,
        uint256 amountBase
    ) internal view returns (uint256, uint256) {
        uint256 baseBalance = baseToken.balanceOf(address(this)) - amountBase;
        uint256 vestedBalance = vestedtoken.balanceOf(address(this)) - amountVested;

        return (vestedBalance, baseBalance);
    }

    function _vestedBalance() internal view returns (uint256) {
        return vestedtoken.balanceOf(address(this));
    }

    function _baseBalance() internal view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }
}
