// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ITrexIdentityRegistry} from "./ITrexIdentityRegistry.sol";
import {IComplianceModule} from "./interfaces/IComplianceModule.sol";
import {IModularCompliance} from "./interfaces/IModularCompliance.sol";

/// @notice UUPS-upgradeable modular compliance host. Aggregates pluggable compliance
///         modules plus built-in identity/limit/pause gates. Upgrades are restricted to
///         UPGRADER_ROLE, which production deployments grant exclusively to the
///         TimelockController (min 24h delay). The token remains immutable.
contract TrexModularCompliance is
    IModularCompliance,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    ITrexIdentityRegistry public identityRegistry;
    bool public paused;
    uint256 public maxTransferAmount;
    address public token;
    IComplianceModule[] private modules;
    mapping(address module => bool bound) public moduleBound;

    uint256[44] private __gap;

    event CompliancePaused(bool paused, address indexed operator);
    event LimitsUpdated(uint256 maxTransferAmount, address indexed operator);
    event TokenBound(address indexed token);
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);

    error InvalidWallet();
    error InvalidModule();
    error ModuleAlreadyBound(address module);
    error ModuleNotBound(address module);
    error TokenAlreadyBound();
    error NotBoundToken();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address superAdmin,
        address governanceAgent,
        address identityRegistryAddress
    ) external initializer {
        if (
            superAdmin == address(0) || governanceAgent == address(0)
                || identityRegistryAddress == address(0)
        ) {
            revert InvalidWallet();
        }
        __AccessControl_init();

        identityRegistry = ITrexIdentityRegistry(identityRegistryAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(GOVERNANCE_ROLE, governanceAgent);
        // UPGRADER_ROLE is intentionally NOT granted here; the deploy script grants it
        // to the TimelockController and renounces any direct upgrade rights.
    }

    modifier onlyToken() {
        if (msg.sender != token) revert NotBoundToken();
        _;
    }

    function setPaused(bool isPaused) external onlyRole(GOVERNANCE_ROLE) {
        paused = isPaused;
        emit CompliancePaused(isPaused, msg.sender);
    }

    /// @notice Governance-only transfer policy limit (`0` = no cap).
    function setLimits(uint256 maxAmount) external onlyRole(GOVERNANCE_ROLE) {
        maxTransferAmount = maxAmount;
        emit LimitsUpdated(maxAmount, msg.sender);
    }

    function bindToken(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress == address(0)) revert InvalidWallet();
        if (token != address(0)) revert TokenAlreadyBound();
        token = tokenAddress;
        emit TokenBound(tokenAddress);
    }

    function addModule(address module) external onlyRole(GOVERNANCE_ROLE) {
        if (module == address(0)) revert InvalidModule();
        if (moduleBound[module]) revert ModuleAlreadyBound(module);
        moduleBound[module] = true;
        modules.push(IComplianceModule(module));
        emit ModuleAdded(module);
    }

    function removeModule(address module) external onlyRole(GOVERNANCE_ROLE) {
        if (!moduleBound[module]) revert ModuleNotBound(module);
        moduleBound[module] = false;
        uint256 length = modules.length;
        for (uint256 i = 0; i < length; i++) {
            if (address(modules[i]) == module) {
                modules[i] = modules[length - 1];
                modules.pop();
                break;
            }
        }
        emit ModuleRemoved(module);
    }

    function getModules() external view returns (IComplianceModule[] memory) {
        return modules;
    }

    function isWalletVerified(address wallet) external view returns (bool) {
        return identityRegistry.isVerified(wallet);
    }

    function canTransfer(address from, address to, uint256 amount)
        external
        view
        returns (bool)
    {
        if (paused) return false;
        if (maxTransferAmount > 0 && amount > maxTransferAmount) return false;
        if (from != address(0) && !identityRegistry.isVerified(from)) return false;
        if (to != address(0) && !identityRegistry.isVerified(to)) return false;

        uint256 length = modules.length;
        for (uint256 i = 0; i < length; i++) {
            if (!modules[i].moduleCheck(from, to, amount, address(this))) return false;
        }
        return true;
    }

    function transferred(address from, address to, uint256 amount) external onlyToken {
        uint256 length = modules.length;
        for (uint256 i = 0; i < length; i++) {
            modules[i].moduleTransferAction(from, to, amount);
        }
    }

    function created(address to, uint256 amount) external onlyToken {
        uint256 length = modules.length;
        for (uint256 i = 0; i < length; i++) {
            modules[i].moduleMintAction(to, amount);
        }
    }

    function destroyed(address from, uint256 amount) external onlyToken {
        uint256 length = modules.length;
        for (uint256 i = 0; i < length; i++) {
            modules[i].moduleBurnAction(from, amount);
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
