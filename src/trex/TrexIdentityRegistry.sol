// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ITrexIdentityRegistry} from "./ITrexIdentityRegistry.sol";
import {ClaimTopicsRegistry} from "./registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "./registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "./registry/IdentityRegistryStorage.sol";

contract TrexIdentityRegistry is AccessControl, ITrexIdentityRegistry {
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    struct Identity {
        bool verified;
        bytes32 referenceHash;
        uint64 approvedAt;
        uint64 revokedAt;
    }

    mapping(address wallet => Identity identity) private identities;

    // ERC-3643 configuration surface. Optional: when unset, behavior is unchanged.
    ClaimTopicsRegistry public claimTopicsRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    IdentityRegistryStorage public identityStorage;

    event RegistriesBound(address claimTopics, address trustedIssuers, address identityStorage);

    event IdentityRegistered(
        address indexed wallet,
        bytes32 indexed referenceHash,
        address indexed operator
    );
    event IdentityRemoved(
        address indexed wallet,
        bytes32 indexed referenceHash,
        address indexed operator
    );

    error InvalidWallet();
    error InvalidReferenceHash();
    error IdentityAlreadyRegistered(address wallet);
    error IdentityNotRegistered(address wallet);

    constructor(address superAdmin, address complianceAgent) {
        if (superAdmin == address(0) || complianceAgent == address(0)) {
            revert InvalidWallet();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(COMPLIANCE_ROLE, complianceAgent);
    }

    /// @notice Bind the ERC-3643 configuration/storage contracts (admin only, additive).
    function bindRegistries(
        address claimTopics,
        address trustedIssuers,
        address storageAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimTopicsRegistry = ClaimTopicsRegistry(claimTopics);
        trustedIssuersRegistry = TrustedIssuersRegistry(trustedIssuers);
        identityStorage = IdentityRegistryStorage(storageAddress);
        emit RegistriesBound(claimTopics, trustedIssuers, storageAddress);
    }

    function registerIdentity(
        address wallet,
        bytes32 referenceHash
    ) external onlyRole(COMPLIANCE_ROLE) {
        _registerIdentity(wallet, referenceHash, 0);
    }

    /// @notice Register with the investor's ISO-3166 jurisdiction code (used by JurisdictionAllowModule).
    function registerIdentity(
        address wallet,
        bytes32 referenceHash,
        uint16 country
    ) external onlyRole(COMPLIANCE_ROLE) {
        _registerIdentity(wallet, referenceHash, country);
    }

    function _registerIdentity(address wallet, bytes32 referenceHash, uint16 country) private {
        if (wallet == address(0)) revert InvalidWallet();
        if (referenceHash == bytes32(0)) revert InvalidReferenceHash();
        if (identities[wallet].verified) revert IdentityAlreadyRegistered(wallet);

        identities[wallet] = Identity({
            verified: true,
            referenceHash: referenceHash,
            approvedAt: uint64(block.timestamp),
            revokedAt: 0
        });

        if (address(identityStorage) != address(0)) {
            identityStorage.storeIdentity(wallet, referenceHash, country);
        }

        emit IdentityRegistered(wallet, referenceHash, msg.sender);
    }

    /// @notice ERC-3643-aligned alias for identity revocation.
    function deleteIdentity(address wallet) external onlyRole(COMPLIANCE_ROLE) {
        _removeIdentity(wallet);
    }

    function removeIdentity(address wallet) external onlyRole(COMPLIANCE_ROLE) {
        _removeIdentity(wallet);
    }

    function _removeIdentity(address wallet) private {
        if (wallet == address(0)) revert InvalidWallet();

        Identity storage identity = identities[wallet];
        if (!identity.verified) revert IdentityNotRegistered(wallet);

        identity.verified = false;
        identity.revokedAt = uint64(block.timestamp);

        if (address(identityStorage) != address(0)) {
            identityStorage.revokeIdentity(wallet);
        }

        emit IdentityRemoved(wallet, identity.referenceHash, msg.sender);
    }

    function isVerified(address wallet) external view returns (bool) {
        return identities[wallet].verified;
    }

    function getIdentity(address wallet) external view returns (Identity memory) {
        return identities[wallet];
    }
}
