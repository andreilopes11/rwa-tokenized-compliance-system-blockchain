// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseComplianceModule} from "./BaseComplianceModule.sol";

/// @notice Module-level pause that blocks all transfer/mint/burn paths when active.
contract PauseModule is BaseComplianceModule {
    bool public paused;

    event ModulePauseSet(bool paused, address indexed operator);

    constructor(address compliance_, address owner_) BaseComplianceModule(compliance_, owner_) {}

    function setPaused(bool isPaused) external onlyOwner {
        paused = isPaused;
        emit ModulePauseSet(isPaused, msg.sender);
    }

    function moduleCheck(address, address, uint256, address querying)
        external
        view
        returns (bool)
    {
        if (!_boundCompliance(querying)) return false;
        return !paused;
    }

    function name() external pure returns (string memory) {
        return "PauseModule";
    }
}
