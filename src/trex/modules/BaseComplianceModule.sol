// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IComplianceModule} from "../interfaces/IComplianceModule.sol";

/// @notice Base for compliance modules. Each module instance is bound to exactly one
///         ModularCompliance; action hooks may only be invoked by that compliance.
///         Configuration is owner-gated (governance Safe or compliance principal).
abstract contract BaseComplianceModule is IComplianceModule, Ownable {
    address public immutable compliance;

    error NotCompliance();
    error InvalidCompliance();

    constructor(address compliance_, address owner_) Ownable(owner_) {
        if (compliance_ == address(0)) revert InvalidCompliance();
        compliance = compliance_;
    }

    modifier onlyCompliance() {
        if (msg.sender != compliance) revert NotCompliance();
        _;
    }

    function moduleTransferAction(address, address, uint256) external virtual onlyCompliance {}

    function moduleMintAction(address, uint256) external virtual onlyCompliance {}

    function moduleBurnAction(address, uint256) external virtual onlyCompliance {}

    function _boundCompliance(address querying) internal view returns (bool) {
        return querying == compliance;
    }
}
