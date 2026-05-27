// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        if (
            governanceAgent == complianceAgent || governanceAgent == superAdmin
                || complianceAgent == superAdmin
        ) {
            revert OverlappingRoleAssignments();
        }

        vm.startBroadcast(privateKey);
        identityRegistry = new TrexIdentityRegistry(superAdmin, complianceAgent);
        modularCompliance =
            new TrexModularCompliance(superAdmin, governanceAgent, address(identityRegistry));
        token = new TrexToken(
            "VaultGuard Tokenized RWA",
            "VGRWA",
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(modularCompliance)
        );
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
}
