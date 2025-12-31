// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVestingController} from "src/interfaces/IVestingController.sol";
import {IVestingShares} from "src/interfaces/IVestingShares.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {IAddressRegistry} from "src/interfaces/IAddressRegistry.sol";

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
    // IERC20 public  vestingToken;
    // IVestingShares public  vestingShares;
    // IVestingController public  controller;
    IAddressRegistry public immutable addressRegistry;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 lastReleaseTime;
    }

    // maps a beneficiary to its vesting schedule
    mapping(address => VestingSchedule) public schedules;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);

    event TokensClaimed(address indexed beneficiary, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry) {
        if (registry == address(0) ) {
            revert VestingCore__ZeroAddress();
        }

        addressRegistry = IAddressRegistry(registry);
        // vestingToken = IERC20(_token);
        // controller = IVestingController(_controller);
        // vestingShares = IVestingShares(_vestingShares);
    }

    /*//////////////////////////////////////////////////////////////
                          SCHEDULE CREATION
    //////////////////////////////////////////////////////////////*/
    function createVestingSchedule(address beneficiary, uint256 amount) external{
        if (beneficiary == address(0)) {
            revert VestingCore__ZeroAddress();
        }
      
        if (amount == 0) {
            revert VestingCore__ZeroAmount();
        }
        IERC20 vestingToken = IERC20(addressRegistry.getVestedTokenAddress());
        IVestingShares vestingShares = IVestingShares(addressRegistry.getVestingShareTokenAddress());   

        VestingSchedule storage s = schedules[beneficiary];

        if (s.totalAmount !=0){
            s.totalAmount += amount;
        }else{
            schedules[beneficiary] = VestingSchedule({
                beneficiary: beneficiary,
                totalAmount: amount,
                claimedAmount: 0,
                lastReleaseTime: block.timestamp
            });
        }

        // it is assumeed that ```approve()``` has already been called on the token
        bool ok = vestingToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) {
            revert VestingCore__TokenTransferFailed();
        }
        //Mint vesting shares 1:1 with locked tokens
        vestingShares.mint(beneficiary, amount);

        emit VestingScheduleCreated(beneficiary, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function claim(uint256 amount) external {
        VestingSchedule storage s = schedules[msg.sender];
        if (s.beneficiary == address(0)) {
            revert VestingCore__NotBeneficiary();
        }
        if (amount == 0) revert VestingCore__ZeroAmount();

        IVestingController controller = IVestingController(addressRegistry.getVestingControllerAddress());
        IVestingShares vestingShares = IVestingShares(addressRegistry.getVestingShareTokenAddress());
        IERC20 vestingToken = IERC20(addressRegistry.getVestedTokenAddress());

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

        if (amount >= releasable){
            amount = releasable;
        }

        s.claimedAmount += amount;
        s.lastReleaseTime += periodsElapsed * periodDuration;

        //Burn shares equal to claimed tokens
        vestingShares.burn(s.beneficiary, amount);

        if (!vestingToken.transfer(s.beneficiary, amount)) {
            revert VestingCore__TokenTransferFailed();
        }

        emit TokensClaimed(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    function remaining(address beneficiary) external view returns (uint256) {
        VestingSchedule memory s = schedules[beneficiary];
        return s.totalAmount - s.claimedAmount;
    }

    function calculateReleasable(VestingSchedule storage s)
        internal
        view
        returns (uint256 releasable, uint256 periodsElapsed, uint256 periodDuration)
    {
        IVestingController controller = IVestingController(addressRegistry.getVestingControllerAddress());
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
