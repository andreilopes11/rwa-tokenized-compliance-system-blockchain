// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseComplianceModule} from "./BaseComplianceModule.sol";
import {IdentityRegistryStorage} from "../registry/IdentityRegistryStorage.sol";

/// @notice Per-tenant jurisdiction allowlist. A recipient's ISO-3166 country (from the
///         IdentityRegistryStorage) must be on the allowlist for it to receive tokens.
contract JurisdictionAllowModule is BaseComplianceModule {
    IdentityRegistryStorage public immutable identityStorage;
    mapping(uint16 country => bool allowed) public allowedJurisdiction;

    event JurisdictionSet(uint16 indexed country, bool allowed);

    error InvalidStorage();

    constructor(address compliance_, address owner_, address identityStorage_)
        BaseComplianceModule(compliance_, owner_)
    {
        if (identityStorage_ == address(0)) revert InvalidStorage();
        identityStorage = IdentityRegistryStorage(identityStorage_);
    }

    function setJurisdiction(uint16 country, bool allowed) external onlyOwner {
        allowedJurisdiction[country] = allowed;
        emit JurisdictionSet(country, allowed);
    }

    function moduleCheck(address, address to, uint256, address querying)
        external
        view
        returns (bool)
    {
        if (!_boundCompliance(querying)) return false;
        if (to == address(0)) return true;
        return allowedJurisdiction[identityStorage.identityCountry(to)];
    }

    function name() external pure returns (string memory) {
        return "JurisdictionAllowModule";
    }
}
