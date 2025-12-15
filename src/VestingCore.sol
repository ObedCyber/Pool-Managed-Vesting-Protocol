// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// import {IVestingPolicy} from "./interfaces/IVestingPolicy.sol";
import {IVestingShares} from "./interfaces/IVestingShares.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingCore {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error VestingCore__NotAuthorized();
    error VestingCore__InvalidSchedule();
    error VestingCore__VestingPaused();
    error VestingCore__NothingToClaim();
    error VestingCore__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event VestingCreated(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event Claimed(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event VestingPausedByPolicy(uint256 indexed scheduleId);
    event VestingResumedByPolicy(uint256 indexed scheduleId);
    event VestingRateUpdated(uint256 indexed scheduleId, uint256 newRate);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount; // total tokens locked
        uint256 claimedAmount; // already claimed
        uint256 vestingRate; // tokens per second (or per epoch)
        uint256 lastClaimTime;
        bool paused;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    IERC20 public immutable underlyingToken;
    IVestingShares public immutable vestingShares;

    // policy address allowed to control vesting behavior
    address public vestingPolicy;

    uint256 public nextScheduleId;
    mapping(uint256 => VestingSchedule) public schedules;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyPolicy() {
        if (msg.sender != vestingPolicy) revert VestingCore__NotAuthorized();
        _;
    }

    modifier validSchedule(uint256 scheduleId) {
        if (scheduleId >= nextScheduleId) revert VestingCore__InvalidSchedule();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address underlyingToken_, address vestingShares_, address vestingPolicy_) {
        underlyingToken = IERC20(underlyingToken_);
        vestingShares = IVestingShares(vestingShares_);
        vestingPolicy = vestingPolicy_;
    }

    /*//////////////////////////////////////////////////////////////
                        VESTING CREATION (DEPOSIT)
    //////////////////////////////////////////////////////////////*/
    function createVestingSchedule(address beneficiary, uint256 amount, uint256 vestingRate)
        external
        returns (uint256 scheduleId)
    {
        // pull tokens from user
        // It is assumed that the user has already approved the spending of its tokens
        bool success = underlyingToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert VestingCore__TransferFailed();

        // mint vesting shares 1:1 (assumption for now)
        vestingShares.mint(beneficiary, amount);

        scheduleId = nextScheduleId++;

        schedules[scheduleId] = VestingSchedule({
            beneficiary: beneficiary,
            totalAmount: amount,
            claimedAmount: 0,
            vestingRate: vestingRate,
            lastClaimTime: block.timestamp,
            paused: false
        });

        emit VestingCreated(scheduleId, beneficiary, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////*/
    function claim(uint256 scheduleId) external validSchedule(scheduleId) {
        VestingSchedule storage s = schedules[scheduleId];

        if (s.paused) revert VestingCore__VestingPaused();
        if (msg.sender != s.beneficiary) revert VestingCore__NotAuthorized();

        uint256 vested = _vestedAmount(s);
        uint256 claimable = vested - s.claimedAmount;

        if (claimable == 0) revert VestingCore__NothingToClaim();

        s.claimedAmount += claimable;
        s.lastClaimTime = block.timestamp;

        // burn shares equal to claim
        vestingShares.burn(msg.sender, claimable);

        // transfer underlying tokens
        bool success = underlyingToken.transfer(msg.sender, claimable);
        if (!success) revert VestingCore__TransferFailed();

        emit Claimed(scheduleId, msg.sender, claimable);
    }

    /*//////////////////////////////////////////////////////////////
                        POLICY-CONTROLLED FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function updateVestingRate(uint256 scheduleId, uint256 newRate) external onlyPolicy validSchedule(scheduleId) {
        schedules[scheduleId].vestingRate = newRate;
        emit VestingRateUpdated(scheduleId, newRate);
    }

    function pauseVesting(uint256 scheduleId) external onlyPolicy validSchedule(scheduleId) {
        schedules[scheduleId].paused = true;
        emit VestingPausedByPolicy(scheduleId);
    }

    function resumeVesting(uint256 scheduleId) external onlyPolicy validSchedule(scheduleId) {
        schedules[scheduleId].paused = false;
        emit VestingResumedByPolicy(scheduleId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VESTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // This function returns the total tokens you are entitled to (both claimed and newly unlocked)
    function _vestedAmount(VestingSchedule memory s) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - s.lastClaimTime;
        uint256 vested = elapsed * s.vestingRate;

        uint256 remaining = s.totalAmount - s.claimedAmount;
        if (vested > remaining) vested = remaining;

        return s.claimedAmount + vested;
    }
}
