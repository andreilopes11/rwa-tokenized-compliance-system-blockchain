// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IdentityRegistry is Ownable {
    struct Identity {
        bool verified;
        bytes32 identityHash;
        uint64 approvedAt;
        uint64 revokedAt;
    }

    mapping(address wallet => Identity identity) private identities;

    event IdentityAdded(
        address indexed wallet,
        bytes32 indexed identityHash,
        address indexed operator
    );
    event IdentityRevoked(
        address indexed wallet,
        bytes32 indexed identityHash,
        address indexed operator
    );

    error InvalidWallet();
    error InvalidIdentityHash();
    error IdentityAlreadyVerified(address wallet);
    error IdentityNotVerified(address wallet);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert InvalidWallet();
    }

    function addIdentity(address wallet, bytes32 identityHash) external onlyOwner {
        if (wallet == address(0)) revert InvalidWallet();
        if (identityHash == bytes32(0)) revert InvalidIdentityHash();
        if (identities[wallet].verified) revert IdentityAlreadyVerified(wallet);

        identities[wallet] = Identity({
            verified: true,
            identityHash: identityHash,
            approvedAt: uint64(block.timestamp),
            revokedAt: 0
        });

        emit IdentityAdded(wallet, identityHash, msg.sender);
    }

    function revokeIdentity(address wallet) external onlyOwner {
        if (wallet == address(0)) revert InvalidWallet();

        Identity storage identity = identities[wallet];
        if (!identity.verified) revert IdentityNotVerified(wallet);

        identity.verified = false;
        identity.revokedAt = uint64(block.timestamp);

        emit IdentityRevoked(wallet, identity.identityHash, msg.sender);
    }

    function isVerified(address wallet) external view returns (bool) {
        return identities[wallet].verified;
    }

    function getIdentity(address wallet) external view returns (Identity memory) {
        return identities[wallet];
    }
}
