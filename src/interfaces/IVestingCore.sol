// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IVestingCore {
    function createVestingSchedule(address beneficiary, uint256 amount, uint256 vestingRate)
        external
        returns (uint256 scheduleId);

    function claim(uint256 scheduleId) external;
}
