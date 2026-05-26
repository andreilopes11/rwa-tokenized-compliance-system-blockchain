// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../../src/legacy/identity/IdentityRegistry.sol";
import {PermissionedToken} from "../../src/legacy/token/PermissionedToken.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @notice Legacy registry deploy for permissioned RWA tokens. Use when BLOCKCHAIN_PROFILE=mvp.
/// @dev For ERC-3643 / T-REX compliance modules, use DeployTREX.s.sol after lib/T-REX is installed.
contract DeployCore {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event Deployment(
        address indexed identityRegistry,
        address indexed permissionedToken,
        address owner
    );

    function run()
        external
        returns (IdentityRegistry registry, PermissionedToken token)
    {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        registry = new IdentityRegistry(owner);
        token = new PermissionedToken(
            "Tokenized RWA Compliance Share",
            "RWAC",
            address(registry),
            owner
        );
        vm.stopBroadcast();

        _writeDeploymentJson(block.chainid, address(registry), address(token), owner);

        emit Deployment(address(registry), address(token), owner);
    }

    function _writeDeploymentJson(
        uint256 chainId,
        address registry,
        address token,
        address owner
    ) private {
        string memory objectKey = "deployment";
        vm.serializeString(objectKey, "profile", "mvp");
        vm.serializeString(objectKey, "blockchainMode", "mvp");
        vm.serializeAddress(objectKey, "identityRegistry", registry);
        vm.serializeAddress(objectKey, "permissionedToken", token);
        string memory json = vm.serializeAddress(objectKey, "owner", owner);
        vm.writeJson(json, _deploymentJsonPath(chainId));
    }

    function _deploymentJsonPath(uint256 chainId) private pure returns (string memory) {
        return string.concat("deployments/", Strings.toString(chainId), ".json");
    }
}
