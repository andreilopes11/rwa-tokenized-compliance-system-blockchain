// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Canonical storage for investor identity records, shared across registries.
/// @dev Only bound IdentityRegistry contracts (AGENT_ROLE) may mutate. Holds only a
///      bytes32 reference hash (no PII on-chain) plus jurisdiction and lifecycle stamps.
contract IdentityRegistryStorage is AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    struct StoredIdentity {
        bool verified;
        bytes32 referenceHash;
        uint16 country;
        uint64 approvedAt;
        uint64 revokedAt;
    }

    mapping(address wallet => StoredIdentity identity) private identities;

    event IdentityStored(address indexed wallet, bytes32 indexed referenceHash, uint16 country);
    event IdentityUnstored(address indexed wallet);

    error InvalidWallet();
    error InvalidReferenceHash();

    constructor(address admin) {
        if (admin == address(0)) revert InvalidWallet();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function bindIdentityRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (registry == address(0)) revert InvalidWallet();
        _grantRole(AGENT_ROLE, registry);
    }

    function unbindIdentityRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(AGENT_ROLE, registry);
    }

    function storeIdentity(address wallet, bytes32 referenceHash, uint16 country)
        external
        onlyRole(AGENT_ROLE)
    {
        if (wallet == address(0)) revert InvalidWallet();
        if (referenceHash == bytes32(0)) revert InvalidReferenceHash();
        identities[wallet] = StoredIdentity({
            verified: true,
            referenceHash: referenceHash,
            country: country,
            approvedAt: uint64(block.timestamp),
            revokedAt: 0
        });
        emit IdentityStored(wallet, referenceHash, country);
    }

    function revokeIdentity(address wallet) external onlyRole(AGENT_ROLE) {
        StoredIdentity storage identity = identities[wallet];
        identity.verified = false;
        identity.revokedAt = uint64(block.timestamp);
        emit IdentityUnstored(wallet);
    }

    function isVerified(address wallet) external view returns (bool) {
        return identities[wallet].verified;
    }

    function identityCountry(address wallet) external view returns (uint16) {
        return identities[wallet].country;
    }

    function getStoredIdentity(address wallet) external view returns (StoredIdentity memory) {
        return identities[wallet];
    }
}
