// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";

/// @notice Test helper to deploy the upgradeable ModularCompliance behind an ERC1967 proxy.
library TrexDeploy {
    function deployCompliance(address superAdmin, address governanceAgent, address registry)
        internal
        returns (TrexModularCompliance)
    {
        TrexModularCompliance impl = new TrexModularCompliance();
        bytes memory data = abi.encodeCall(
            TrexModularCompliance.initialize, (superAdmin, governanceAgent, registry)
        );
        return TrexModularCompliance(address(new ERC1967Proxy(address(impl), data)));
    }
}
