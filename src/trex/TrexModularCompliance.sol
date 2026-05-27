// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ITrexIdentityRegistry} from "./ITrexIdentityRegistry.sol";

contract TrexModularCompliance is AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    ITrexIdentityRegistry public immutable identityRegistry;
    bool public paused;

    error InvalidWallet();

    event CompliancePaused(bool paused, address indexed operator);

    constructor(
        address superAdmin,
        address governanceAgent,
        address identityRegistryAddress
    ) {
        if (
            superAdmin == address(0) || governanceAgent == address(0)
                || identityRegistryAddress == address(0)
        ) {
            revert InvalidWallet();
        }

        identityRegistry = ITrexIdentityRegistry(identityRegistryAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(GOVERNANCE_ROLE, governanceAgent);
    }

    function setPaused(bool isPaused) external onlyRole(GOVERNANCE_ROLE) {
        paused = isPaused;
        emit CompliancePaused(isPaused, msg.sender);
    }

    function canTransfer(address from, address to, uint256) external view returns (bool) {
        if (paused) return false;
        if (from != address(0) && !identityRegistry.isVerified(from)) return false;
        if (to != address(0) && !identityRegistry.isVerified(to)) return false;
        return true;
    }

    function isWalletVerified(address wallet) external view returns (bool) {
        return identityRegistry.isVerified(wallet);
    }
}
