// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "v3-core/contracts/libraries/FullMath.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IAddressRegistry} from "../interfaces/IAddressRegistry.sol";

contract UniswapV3OracleAdapter {
    /// @notice Address registry for protocol dependencies
    IAddressRegistry public immutable registry;

    /// @notice Uniswap V3 pool used for pricing (VEST / USDC)
    IUniswapV3Pool public immutable pool;

    /// @notice Tokens in the pool
    address public immutable vestToken;
    address public immutable baseToken;

    /// @notice Default TWAP window (seconds)
    uint32 public immutable defaultTwapWindow;

    error Oracle__InvalidToken();
    error Oracle__InvalidTwapWindow();

    constructor(
        address _registry,
        address _pool,
        uint32 _defaultTwapWindow
    ) {
        if(_defaultTwapWindow == 0) {
            revert Oracle__InvalidTwapWindow();
        }

        registry = IAddressRegistry(_registry);
        pool = IUniswapV3Pool(_pool);

        vestToken = pool.token0();
        baseToken = pool.token1();

        defaultTwapWindow = _defaultTwapWindow;
    }

    /// @notice Returns TWAP price of 1 VEST in base token (e.g. USDC)
    function getPrice() external view returns (uint256) {
        return _getTwapPrice(defaultTwapWindow);
    }

    /// @notice Returns TWAP price using a custom window
    function getPriceWithWindow(uint32 window)
        external
        view
        returns (uint256)
    {
        if (window == 0) revert Oracle__InvalidTwapWindow();
        return _getTwapPrice(window);
    }

    function _getTwapPrice(uint32 window)
        internal
        view
        returns (uint256 price)
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = window;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

        int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];
        int24 avgTick = int24(tickDelta / int56(uint56(window)));

        // round toward negative infinity
        if (
            tickDelta < 0 &&
            (tickDelta % int56(uint56(window)) != 0)
        ) {
            avgTick--;
        }

        // Price of 1 VEST in baseToken units
        price = _getQuoteAtTick(
            avgTick,
            1e18, // assume VEST has 18 decimals
            vestToken,
            baseToken
        );
    }

    /// @notice Converts tick to quoted token amount
    function _getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address base,
        address quote
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = base < quote
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 =
                FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = base < quote
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}