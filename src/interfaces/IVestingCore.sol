// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IVestingCore {
    function createVestingSchedule(
        address beneficiary, 
        uint256 amount, 
        uint256 vestingRate
    ) external returns (uint256 scheduleId);

    function claim (uint256 scheduleId) external;

    function updateVestingRate(
        uint256 scheduleId, 
        uint256 newRate
    ) external; 

    function pauseVesting(uint256 scheduleId) external;

    function resumeVesting(uint256 scheduleId) external;
}