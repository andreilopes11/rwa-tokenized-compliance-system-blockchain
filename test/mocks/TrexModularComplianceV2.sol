// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";

/// @notice Upgrade target used only by tests to prove the timelock-gated UUPS upgrade path.
contract TrexModularComplianceV2 is TrexModularCompliance {
    function version() external pure returns (uint256) {
        return 2;
    }
}
