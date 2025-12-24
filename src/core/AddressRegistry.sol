// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AddressRegistry {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error AddressRegistry__Unauthorized();
    error AddressRegistry__ZeroAddress();
    error AddressRegistry__AddressNotRegistered();

    // Mapping of role/key => address
    mapping(bytes32 => address) private addresses;

    // the address of the person that can update the registry
    address public admin;

    // Common role keys (use these consistently across the system)
    bytes32 public constant VESTING_CORE = keccak256("VESTING_CORE");
    bytes32 public constant BASE_TOKEN = keccak256("BASE_TOKEN"); // the ERC20 token paired with the base token to create liquidity
    bytes32 public constant VESTED_TOKEN = keccak256("VESTED_TOKEN"); // the main ERC20 token being vested
    bytes32 public constant VESTING_SHARE_TOKEN = keccak256("VESTING_SHARE_TOKEN");
    bytes32 public constant LIQUIDITY_MANAGER = keccak256("LIQUIDITY_MANAGER");
    bytes32 public constant PRICE_ORACLE_ADAPTER = keccak256("PRICE_ORACLE_ADAPTER");
    bytes32 public constant TREASURY = keccak256("TREASURY");
    bytes32 public constant VESTING_CONTROLLER = keccak256("VESTING_CONTROLLER");
    bytes32 public constant LIQUIDITY_CONTROLLER = keccak256("LIQUIDITY_CONTROLLER");

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event AddressSet(bytes32 indexed key, address indexed oldAddress, address indexed newAddress);
    event AddressRemoved(bytes32 indexed key);

    constructor(address initialAdmin) {
        admin = initialAdmin;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert AddressRegistry__Unauthorized();
        _;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function setAddress(bytes32 key, address addr) external onlyAdmin {
        if (addr == address(0)) revert AddressRegistry__ZeroAddress();
        address old = addresses[key];
        addresses[key] = addr;

        emit AddressSet(key, old, addr);
    }

    /**
     * @dev Remove an address (set to zero). Useful for decommissioning components.
     */
    function removeAddress(bytes32 key) external onlyAdmin {
        address old = addresses[key];
        require(old != address(0), "AddressRegistry: address not set");

        delete addresses[key];
        emit AddressRemoved(key);
    }

    /**
     * @dev Get address for a key. Reverts if not set.
     */
    function getAddress(bytes32 key) public view returns (address) {
        address addr = addresses[key];
        if (addr == address(0)) revert AddressRegistry__AddressNotRegistered();
        return addr;
    }

    // Convenience getters for common roles
    function getVestingCoreAddress() external view returns (address) {
        return getAddress(VESTING_CORE);
    }

    function vestingShareToken() external view returns (address) {
        return getAddress(VESTING_SHARE_TOKEN);
    }

    function liquidityManager() external view returns (address) {
        return getAddress(LIQUIDITY_MANAGER);
    }

    function priceOracleAdapter() external view returns (address) {
        return getAddress(PRICE_ORACLE_ADAPTER);
    }

    function getBaseTokenAddress() external view returns (address) {
        return getAddress(BASE_TOKEN);
    }

    function getTreasuryAddress() external view returns (address) {
        return getAddress(TREASURY);
    }

    function getVestingControllerAddress() external view returns (address) {
        return getAddress(VESTING_CONTROLLER);
    }

    function getLiquidityController() external view returns (address) {
        return getAddress(LIQUIDITY_CONTROLLER);
    }

    function getVestedTokenAddress() external view returns (address) {
        return getAddress(VESTED_TOKEN);
    }
}
