// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

/*//////////////////////////////////////////////////////////////
                        VESTING CONTROLLER
//////////////////////////////////////////////////////////////*/

contract VestingController is AutomationCompatibleInterface {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error VestingController__OracleError();
    error VestingController__InvalidParams();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PolicyUpdated(
        uint256 periodDuration,
        uint256 tokensPerPeriod,
        bool paused
    );

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    IPriceOracle public immutable oracle;

    // Global vesting parameters
    uint256 public periodDuration;
    uint256 public tokensPerPeriod;
    bool public paused;

    // Price thresholds
    uint256 public immutable highPriceThreshold;
    uint256 public immutable lowPriceThreshold;
    uint256 public immutable criticalLowPrice;
    uint256 public immutable recoveryPrice;

    // Safety bounds
    uint256 public immutable minPeriodDuration;
    uint256 public immutable maxPeriodDuration;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _oracle,
        uint256 _initialPeriodDuration,
        uint256 _initialTokensPerPeriod,
        uint256 _highPriceThreshold,
        uint256 _lowPriceThreshold,
        uint256 _criticalLowPrice,
        uint256 _recoveryPrice,
        uint256 _minPeriodDuration,
        uint256 _maxPeriodDuration
    ) {
        if (
            _oracle == address(0) ||
            _initialPeriodDuration == 0 ||
            _initialTokensPerPeriod == 0 ||
            _criticalLowPrice >= _lowPriceThreshold ||
            _lowPriceThreshold >= _highPriceThreshold ||
            _recoveryPrice <= _lowPriceThreshold ||
            _minPeriodDuration >= _maxPeriodDuration ||
            _initialPeriodDuration < _minPeriodDuration ||
            _initialPeriodDuration > _maxPeriodDuration
        ) revert VestingController__InvalidParams();

        oracle = IPriceOracle(_oracle);

        periodDuration = _initialPeriodDuration;
        tokensPerPeriod = _initialTokensPerPeriod;

        highPriceThreshold = _highPriceThreshold;
        lowPriceThreshold = _lowPriceThreshold;
        criticalLowPrice = _criticalLowPrice;
        recoveryPrice = _recoveryPrice;

        minPeriodDuration = _minPeriodDuration;
        maxPeriodDuration = _maxPeriodDuration;
    }

    /*//////////////////////////////////////////////////////////////
                        CHAINLINK AUTOMATION
    //////////////////////////////////////////////////////////////*/

    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory)
    {
        uint256 price = oracle.getPrice();
        if (price == 0) revert VestingController__OracleError();

        if (
            price <= criticalLowPrice ||
            price >= recoveryPrice ||
            price < lowPriceThreshold ||
            price > highPriceThreshold
        ) {
            return (true, bytes(""));
        }

        return (false, bytes(""));
    }

    function performUpkeep(bytes calldata) external override {
        uint256 price = oracle.getPrice();
        if (price == 0) revert VestingController__OracleError();

        /*//////////////////////////////////////////////////////////////
                            PAUSE / UNPAUSE
        //////////////////////////////////////////////////////////////*/

        if (price <= criticalLowPrice) {
            paused = true;
        } else if (price >= recoveryPrice) {
            paused = false;
        }

        /*//////////////////////////////////////////////////////////////
                    RATE ADJUSTMENT (ONLY IF ACTIVE)
        //////////////////////////////////////////////////////////////*/

        if (!paused) {
            if (price > highPriceThreshold) {
                _accelerate();
            } else if (price < lowPriceThreshold) {
                _decelerate();
            }
        }

        emit PolicyUpdated(periodDuration, tokensPerPeriod, paused);
    }

    /*//////////////////////////////////////////////////////////////
                        POLICY LOGIC
    //////////////////////////////////////////////////////////////*/

    function _accelerate() internal {
        if (periodDuration > minPeriodDuration) {
            periodDuration = (periodDuration * 80) / 100; // -20%
        }

        if (periodDuration < minPeriodDuration) {
            periodDuration = minPeriodDuration;
        }
    }

    function _decelerate() internal {
        if (periodDuration < maxPeriodDuration) {
            periodDuration = (periodDuration * 120) / 100; // +20%
        }

        if (periodDuration > maxPeriodDuration) {
            periodDuration = maxPeriodDuration;
        }
    }

    function getVestingParams() external view returns(uint256, uint256){
        return (tokensPerPeriod, periodDuration);
    }

    function isPaused() external view returns (bool){
        return paused;
    }
}
