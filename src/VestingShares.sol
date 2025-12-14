// SPDX-license-Identifier: MIT
pragma solidity ^0.8.30;

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VestingShares is ERC20 {
    error VestingShares__NotVestingCore();
    error VestingShares__ZeroAddress();

    address public immutable vestingCore;

    modifier onlyVestingCore() {
        if (msg.sender != vestingCore) revert VestingShares__NotVestingCore();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _vestingCore
    ) ERC20(_name, _symbol) {
        if (_vestingCore == address(0)) revert VestingShares__ZeroAddress();
        vestingCore = _vestingCore;
    }

    /*//////////////////////////////////////////////////////////////
                            MINT / BURN
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external onlyVestingCore {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyVestingCore {
        _burn(from, amount);
    }
}
