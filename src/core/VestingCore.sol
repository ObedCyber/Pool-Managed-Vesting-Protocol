// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVestingController} from "src/interfaces/IVestingController.sol";
import {IVestingShares} from "src/interfaces/IVestingShares.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract VestingCore {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error VestingCore__NotBeneficiary();
    error VestingCore__InvalidSchedule();
    error VestingCore__VestingPaused();
    error VestingCore__NothingToClaim();
    error VestingCore__InvalidParams();
    error VestingCore__ZeroAddress();
    error VestingCore__ZeroAmount();
    error VestingCore__TokenTransferFailed();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_PERIOD = 1 days;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable vestingToken;
    IVestingShares public immutable vestingShares;
    IVestingController public controller;

    uint256 public nextScheduleId;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 lastReleaseTime;
    }

    mapping(uint256 => VestingSchedule) public schedules;
    mapping(address => VestingSchedule[]) public schedulesOf;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event VestingScheduleCreated(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);

    event TokensClaimed(uint256 indexed scheduleId, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _token, address _controller, address _vestingShares) {
        if (_token == address(0) || _controller == address(0) || _vestingShares == address(0)) {
            revert VestingCore__ZeroAddress();
        }

        vestingToken = IERC20(_token);
        controller = IVestingController(_controller);
        vestingShares = IVestingShares(_vestingShares);
    }

    /*//////////////////////////////////////////////////////////////
                          SCHEDULE CREATION
    //////////////////////////////////////////////////////////////*/
    function createVestingSchedule(address beneficiary, uint256 amount) external returns (uint256 scheduleId) {
        if (beneficiary == address(0)) {
            revert VestingCore__ZeroAddress();
        }

        if (amount == 0) {
            revert VestingCore__ZeroAmount();
        }
        // it is assumeed that ```approve()``` has already been called on the token
        bool ok = vestingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) {
            revert VestingCore__TokenTransferFailed();
        }

        scheduleId = nextScheduleId++;

        schedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            claimedAmount: 0,
            lastReleaseTime: block.timestamp
        });

        //Mint vesting shares 1:1 with locked tokens
        vestingShares.mint(beneficiary, amount);

        // schedulesOf[msg.sender].push(VestingSchedule({
        //     beneficiary: beneficiary,
        //     totalAmount: amount,
        //     claimedAmount: 0,
        //     lastReleaseTime: block.timestamp
        // }));

        emit VestingScheduleCreated(scheduleId, beneficiary, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function claim(uint256 scheduleId) external {
        if (scheduleId >= nextScheduleId) revert VestingCore__InvalidSchedule();
        VestingSchedule storage s = schedules[scheduleId];

        if (msg.sender != s.beneficiary) {
            revert VestingCore__NotBeneficiary();
        }

        if (controller.isPaused()) {
            revert VestingCore__VestingPaused();
        }

        (uint256 releasable, uint256 periodsElapsed, uint256 periodDuration) = calculateReleasable(s);

        if (releasable > s.totalAmount - s.claimedAmount) {
            releasable = s.totalAmount - s.claimedAmount; //remaining tokens to be claimed
        }

        if (releasable == 0) {
            revert VestingCore__NothingToClaim();
        }

        s.claimedAmount += releasable;
        s.lastReleaseTime += periodsElapsed * periodDuration;

        //Burn shares equal to claimed tokens
        vestingShares.burn(s.beneficiary, releasable);

        if (!vestingToken.transfer(s.beneficiary, releasable)) {
            revert VestingCore__TokenTransferFailed();
        }

        emit TokensClaimed(scheduleId, releasable);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function remaining(uint256 scheduleId) external view returns (uint256) {
        VestingSchedule memory s = schedules[scheduleId];
        return s.totalAmount - s.claimedAmount;
    }

    function calculateReleasable(VestingSchedule storage s)
        internal
        view
        returns (uint256 releasable, uint256 periodsElapsed, uint256 periodDuration)
    {
        (uint256 periodDuration, uint256 tokensPerPeriod) = controller.getVestingParams();

        if (periodDuration < MIN_PERIOD || tokensPerPeriod == 0) {
            revert VestingCore__InvalidParams();
        }

        uint256 elapsed = block.timestamp - s.lastReleaseTime;
        periodsElapsed = elapsed / periodDuration;

        if (periodsElapsed == 0) {
            revert VestingCore__NothingToClaim();
        }

        releasable = periodsElapsed * tokensPerPeriod;
    }
}
