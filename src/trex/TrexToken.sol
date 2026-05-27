// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {TrexModularCompliance} from "./TrexModularCompliance.sol";

contract TrexToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIFECYCLE_ROLE = keccak256("LIFECYCLE_ROLE");
    bytes32 public constant TRANSFER_MANAGER_ROLE =
        keccak256("TRANSFER_MANAGER_ROLE");

    TrexModularCompliance public immutable modularCompliance;
    bool public paused;

    error InvalidCompliance();
    error NonCompliantSender(address wallet);
    error NonCompliantRecipient(address wallet);
    error TokenPaused();

    event ForcedTransfer(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Paused(address indexed operator);
    event Unpaused(address indexed operator);

    constructor(
        string memory name_,
        string memory symbol_,
        address superAdmin,
        address governanceAgent,
        address lifecycleAgent,
        address transferManagerAgent,
        address modularComplianceAddress
    ) ERC20(name_, symbol_) {
        if (modularComplianceAddress == address(0)) revert InvalidCompliance();

        modularCompliance = TrexModularCompliance(modularComplianceAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(GOVERNANCE_ROLE, governanceAgent);
        _grantRole(LIFECYCLE_ROLE, lifecycleAgent);
        _grantRole(TRANSFER_MANAGER_ROLE, transferManagerAgent);
    }

    function mint(address to, uint256 amount) external onlyRole(LIFECYCLE_ROLE) {
        _mint(to, amount);
    }

    function pause() external onlyRole(GOVERNANCE_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(GOVERNANCE_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function forceTransfer(
        address from,
        address to,
        uint256 amount
    ) external onlyRole(TRANSFER_MANAGER_ROLE) {
        _transfer(from, to, amount);
        emit ForcedTransfer(msg.sender, from, to, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (paused) revert TokenPaused();

        // Final compliance gate at execution time.
        if (
            from != address(0)
                && !modularCompliance.isWalletVerified(from)
        ) {
            revert NonCompliantSender(from);
        }
        if (to != address(0) && !modularCompliance.isWalletVerified(to)) {
            revert NonCompliantRecipient(to);
        }
        if (!modularCompliance.canTransfer(from, to, amount)) revert TokenPaused();

        super._update(from, to, amount);
    }
}
