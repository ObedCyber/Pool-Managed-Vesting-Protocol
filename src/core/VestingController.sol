// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAddressRegistry} from "src/interfaces/IAddressRegistry.sol";

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

contract VestingController is AutomationCompatibleInterface {
    error VestingController__OracleError();
    error VestingController__InvalidParams();

    event PolicyUpdated(uint256 periodDuration, uint256 tokensPerPeriod, bool paused, uint256 newLastPrice);

    IAddressRegistry public immutable addressRegistry;

    enum Action{
        NONE,
        ACCELERATE,
        DECELERATE,
        PAUSE,
        UNPAUSE
    }

    // Global vesting parameters
    uint256 public periodDuration;
    uint256 public tokensPerPeriod;
    bool public paused;

    // Relative movement tracking
    uint256 public lastPrice; // @dev Tracks the price at the last adjustment
    
    // Safety bounds
    uint256 public immutable minPeriodDuration;
    uint256 public immutable maxPeriodDuration;
    uint256 public immutable criticalLowPrice;
    uint256 public immutable recoveryPrice;

    constructor(
        address _addressRegistry,
        uint256 _initialPeriodDuration,
        uint256 _initialTokensPerPeriod,
        uint256 _minPeriodDuration,
        uint256 _maxPeriodDuration
    ) {
        if (_addressRegistry == address(0) || _initialTokensPerPeriod == 0
            || _minPeriodDuration >= _maxPeriodDuration
            || _initialPeriodDuration < _minPeriodDuration || _initialPeriodDuration > _maxPeriodDuration
        ) revert VestingController__InvalidParams();

        addressRegistry = IAddressRegistry(_addressRegistry);
        
        // Initialize price tracking
        IPriceOracle oracle = IPriceOracle(IAddressRegistry(_addressRegistry).getPriceOracleAdapterAddress());
        lastPrice = oracle.getPrice();
        if (lastPrice == 0) revert VestingController__OracleError();

        periodDuration = _initialPeriodDuration;
        tokensPerPeriod = _initialTokensPerPeriod;
        minPeriodDuration = _minPeriodDuration;
        maxPeriodDuration = _maxPeriodDuration;
        criticalLowPrice = (lastPrice * 50) / 100; // 50 percent of its initial value
        recoveryPrice = (criticalLowPrice * 110) / 100; 
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        IPriceOracle oracle = IPriceOracle(addressRegistry.getPriceOracleAdapterAddress());
        uint256 currentPrice = oracle.getPrice();
        if (currentPrice == 0) revert VestingController__OracleError();

        // Check for 10% movement (Up or Down)
        bool priceMovedUp = currentPrice >= (lastPrice * 110) / 100 && !paused;
        bool priceMovedDown = 
            currentPrice <= (lastPrice * 90) / 100 && currentPrice > criticalLowPrice && !paused; 
        bool pauseVesting = currentPrice <= criticalLowPrice && !paused;
        bool resumeVesting = currentPrice >= recoveryPrice && paused;

        if(priceMovedUp) {
            return (true, abi.encode(Action.ACCELERATE));
        }
        if (priceMovedDown){
            return(true, abi.encode(Action.DECELERATE));
        }
        if (pauseVesting){
            return(true, abi.encode(Action.PAUSE));
        }
        if (resumeVesting){
            return(true, abi.encode(Action.UNPAUSE));
        }
      

        return (false, bytes(""));
    }

    function performUpkeep(bytes calldata performData) external override {
        Action action = abi.decode(performData, (Action));

        if(action == Action.PAUSE) paused = true;
        if(action == Action.UNPAUSE) paused = false;
        if(action == Action.ACCELERATE) {
            _accelerate();
        }
        if(action == Action.DECELERATE){
            _decelerate();
        }

        lastPrice = IPriceOracle(addressRegistry.getPriceOracleAdapterAddress()).getPrice();

        emit PolicyUpdated(periodDuration, tokensPerPeriod, paused, lastPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            ADJUSTMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _accelerate() internal {
        // Example: decrease duration by 20%
        periodDuration = (periodDuration * 80) / 100;
        if (periodDuration < minPeriodDuration) periodDuration = minPeriodDuration;
    }

    function _decelerate() internal {
        // Example: increase duration by 20%
        periodDuration = (periodDuration * 120) / 100;
        if (periodDuration > maxPeriodDuration) periodDuration = maxPeriodDuration;
    }

    function getVestingParams() external view returns (uint256, uint256) {
        return (tokensPerPeriod, periodDuration);
    }

    function isPaused() external view returns (bool) {
        return paused;
    }
}