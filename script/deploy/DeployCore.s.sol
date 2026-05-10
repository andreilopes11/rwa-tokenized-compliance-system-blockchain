// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";
import {PermissionedToken} from "../../src/token/PermissionedToken.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

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

        string memory objectKey = "deployment";
        vm.serializeAddress(objectKey, "identityRegistry", address(registry));
        vm.serializeAddress(objectKey, "permissionedToken", address(token));
        string memory json = vm.serializeAddress(objectKey, "owner", owner);
        vm.writeJson(
            json,
            string.concat(
                "deployments/",
                Strings.toString(block.chainid),
                ".json"
            )
        );

        emit Deployment(address(registry), address(token), owner);
    }
}
