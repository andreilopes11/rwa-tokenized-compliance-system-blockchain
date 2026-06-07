// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @notice Production TREX-like deployment with explicit role separation.
contract DeployTREX {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event TrexDeployment(
        address indexed identityRegistry,
        address indexed modularCompliance,
        address indexed token,
        address superAdmin,
        address governanceAgent,
        address complianceAgent,
        address lifecycleAgent,
        address transferManagerAgent
    );

    error InvalidRoleAddress();
    error OverlappingRoleAssignments();

    function run()
        external
        returns (
            TrexIdentityRegistry identityRegistry,
            TrexModularCompliance modularCompliance,
            TrexToken token
        )
    {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address superAdmin = vm.addr(privateKey);
        address governanceAgent = vm.addr(vm.envUint("GOVERNANCE_AGENT_PRIVATE_KEY"));
        address complianceAgent = vm.addr(vm.envUint("COMPLIANCE_AGENT_PRIVATE_KEY"));
        address lifecycleAgent = vm.addr(vm.envUint("LIFECYCLE_AGENT_PRIVATE_KEY"));
        address transferManagerAgent =
            vm.addr(vm.envUint("TRANSFER_MANAGER_AGENT_PRIVATE_KEY"));

        if (
            governanceAgent == address(0) || complianceAgent == address(0)
                || lifecycleAgent == address(0) || transferManagerAgent == address(0)
        ) {
            revert InvalidRoleAddress();
        }
        if (_hasOverlappingSoDAssignments(
                superAdmin,
                governanceAgent,
                complianceAgent,
                lifecycleAgent,
                transferManagerAgent
            )) {
            revert OverlappingRoleAssignments();
        }

        vm.startBroadcast(privateKey);
        identityRegistry = new TrexIdentityRegistry(superAdmin, complianceAgent);

        TrexModularCompliance complianceImpl = new TrexModularCompliance();
        bytes memory initData = abi.encodeCall(
            TrexModularCompliance.initialize,
            (superAdmin, governanceAgent, address(identityRegistry))
        );
        modularCompliance =
            TrexModularCompliance(address(new ERC1967Proxy(address(complianceImpl), initData)));

        token = new TrexToken(
            "VaultGuard Tokenized RWA",
            "VGRWA",
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(modularCompliance),
            0
        );
        modularCompliance.bindToken(address(token));
        vm.stopBroadcast();

        _writeDeploymentJson(
            block.chainid,
            address(identityRegistry),
            address(modularCompliance),
            address(token),
            superAdmin,
            governanceAgent,
            complianceAgent,
            lifecycleAgent,
            transferManagerAgent
        );

        emit TrexDeployment(
            address(identityRegistry),
            address(modularCompliance),
            address(token),
            superAdmin,
            governanceAgent,
            complianceAgent,
            lifecycleAgent,
            transferManagerAgent
        );
    }

    function _writeDeploymentJson(
        uint256 chainId,
        address identityRegistry,
        address modularCompliance,
        address token,
        address superAdmin,
        address governanceAgent,
        address complianceAgent,
        address lifecycleAgent,
        address transferManagerAgent
    ) private {
        string memory objectKey = "deployment";
        vm.serializeString(objectKey, "profile", "trex");
        vm.serializeString(objectKey, "blockchainMode", "trex");
        vm.serializeAddress(objectKey, "identityRegistry", identityRegistry);
        vm.serializeAddress(objectKey, "modularCompliance", modularCompliance);
        vm.serializeAddress(objectKey, "token", token);
        vm.serializeAddress(objectKey, "superAdmin", superAdmin);
        vm.serializeAddress(objectKey, "governanceAgent", governanceAgent);
        vm.serializeAddress(objectKey, "complianceAgent", complianceAgent);
        vm.serializeAddress(objectKey, "lifecycleAgent", lifecycleAgent);
        string memory json =
            vm.serializeAddress(objectKey, "transferManagerAgent", transferManagerAgent);
        vm.writeJson(json, _deploymentJsonPath(chainId));
    }

    function _deploymentJsonPath(uint256 chainId) private pure returns (string memory) {
        return string.concat("deployments/", Strings.toString(chainId), ".json");
    }

    /// @dev Governance and compliance agents must never share keys (on-chain SoD).
    /// All privileged agents and super-admin must be unique to avoid key concentration.
    function _hasOverlappingSoDAssignments(
        address superAdmin,
        address governanceAgent,
        address complianceAgent,
        address lifecycleAgent,
        address transferManagerAgent
    ) internal pure returns (bool) {
        if (governanceAgent == complianceAgent) return true;
        if (governanceAgent == superAdmin) return true;
        if (complianceAgent == superAdmin) return true;
        if (governanceAgent == lifecycleAgent) return true;
        if (governanceAgent == transferManagerAgent) return true;
        if (complianceAgent == lifecycleAgent) return true;
        if (complianceAgent == transferManagerAgent) return true;
        if (lifecycleAgent == transferManagerAgent) return true;
        if (lifecycleAgent == superAdmin) return true;
        if (transferManagerAgent == superAdmin) return true;
        return false;
    }
}
