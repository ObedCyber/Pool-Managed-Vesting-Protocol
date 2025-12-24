// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {IAddressRegistry} from "../interfaces/IAddressRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityManager {
    address public immutable registry;
    INonfungiblePositionManager public immutable positionManager;
    address public pool;

    address public immutable token0;
    address public immutable token1;

    uint24 public constant FEE = 3000;
    int24 public constant tickLower = -887220;
    int24 public constant tickUpper = 887220;
    uint256 public positionTokenId;

    error LiquidityManager__NotAuthorized();
    error LiquidityManager__CannotReinitializePool();
    error LiquidityManager__TokenTransferFailed();
    error LiquidityManager__TokenApprovalFailed();

    event LiquidityProvided(uint256 tokenId, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 amount0, uint256 amount1);

    constructor(address _registry, address _positionManager, address _token0, address _token1) {
        registry = _registry;
        positionManager = INonfungiblePositionManager(_positionManager);
        token0 = _token0;
        token1 = _token1;
    }

    modifier onlyController() {
        if (msg.sender != IAddressRegistry(registry).getLiquidityController()) {
            revert LiquidityManager__NotAuthorized();
        }
        _;
    }

    function initPool(uint160 sqrtPriceX96) external onlyController {
        if (pool != address(0)) {
            revert LiquidityManager__CannotReinitializePool();
        }
        pool = positionManager.createAndInitializePoolIfNecessary(token0, token1, FEE, sqrtPriceX96);
    }

    /// @notice Provide liquidity using protocol-controlled tokens
    function provideLiquidity(uint256 amount0Desired, uint256 amount1Desired) external onlyController {
        address treasury = IAddressRegistry(registry).getTreasuryAddress();

        {
            bool ok = IERC20(token0).transferFrom(treasury, address(this), amount0Desired);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }

        {
            bool ok = IERC20(token1).transferFrom(treasury, address(this), amount1Desired);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }

        {
            bool ok = IERC20(token0).approve(address(positionManager), amount0Desired);
            if (!ok) revert LiquidityManager__TokenApprovalFailed();
        }
        {
            bool ok = IERC20(token1).approve(address(positionManager), amount1Desired);
            if (!ok) revert LiquidityManager__TokenApprovalFailed();
        }

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (uint256 tokenId,, uint256 amount0, uint256 amount1) = positionManager.mint(params);

        positionTokenId = tokenId;

        emit LiquidityProvided(tokenId, amount0, amount1);
    }

    /// @notice Remove liquidity from the pool
    function removeLiquidity(uint128 liquidity) external onlyController {
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: positionTokenId,
            liquidity: liquidity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(params);

        // Collect withdrawn liquidity
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        {
            bool ok = IERC20(token0).transfer(IAddressRegistry(registry).getTreasuryAddress(), amount0);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }
        {
            bool ok = IERC20(token1).transfer(IAddressRegistry(registry).getTreasuryAddress(), amount1);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }

        emit LiquidityRemoved(amount0, amount1);
    }

    /// @notice Collect fees earned by the LP position
    function collectFees() external onlyController returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        {
            bool ok = IERC20(token0).transfer(IAddressRegistry(registry).getTreasuryAddress(), amount0);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }

        {
            bool ok = IERC20(token1).transfer(IAddressRegistry(registry).getTreasuryAddress(), amount1);
            if (!ok) revert LiquidityManager__TokenTransferFailed();
        }

        emit FeesCollected(amount0, amount1);
    }

    /// @notice Get the address of the pool
    function getPool() external view returns (address) {
        return pool;
    }

    ///@notice Get the position token ID
    function getPositionTokenId() external view returns (uint256) {
        return positionTokenId;
    }

    ///@notice get the total liquidity of the position
    function getPositionLiquidity() external view returns (uint128 liquidity) {
        (,,,,,,, liquidity,,,,) = positionManager.positions(positionTokenId);
    }
}
