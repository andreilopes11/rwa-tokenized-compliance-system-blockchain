// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @notice Deploys an additional marketplace token + ModularCompliance bound to a
///         **shared** IdentityRegistry (INV-10 preferred mode).
/// @dev Marketplace visibility (PUBLIC/PRIVATE) is off-chain only — never encoded here.
///
/// Required env: PRIVATE_KEY, GOVERNANCE_AGENT_PRIVATE_KEY, LIFECYCLE_AGENT_PRIVATE_KEY,
///   TRANSFER_MANAGER_AGENT_PRIVATE_KEY, SHARED_IDENTITY_REGISTRY,
///   TOKEN_NAME, TOKEN_SYMBOL.
/// Optional: MAX_SUPPLY (default 0 = uncapped).
contract DeployAdditionalTrexToken {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event AdditionalTrexTokenDeployment(
        address indexed sharedIdentityRegistry,
        address indexed modularCompliance,
        address indexed token,
        string name,
        string symbol
    );

    error InvalidSharedRegistry();
    error InvalidRoleAddress();

    function run()
        external
        returns (TrexModularCompliance modularCompliance, TrexToken token)
    {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address superAdmin = vm.addr(privateKey);
        address governanceAgent = vm.addr(vm.envUint("GOVERNANCE_AGENT_PRIVATE_KEY"));
        address lifecycleAgent = vm.addr(vm.envUint("LIFECYCLE_AGENT_PRIVATE_KEY"));
        address transferManagerAgent =
            vm.addr(vm.envUint("TRANSFER_MANAGER_AGENT_PRIVATE_KEY"));
        address sharedRegistry = vm.envAddress("SHARED_IDENTITY_REGISTRY");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(0));

        if (sharedRegistry == address(0)) revert InvalidSharedRegistry();
        if (
            governanceAgent == address(0) || lifecycleAgent == address(0)
                || transferManagerAgent == address(0)
        ) {
            revert InvalidRoleAddress();
        }

        // Confirm the shared registry is a live TrexIdentityRegistry (call reverts otherwise).
        TrexIdentityRegistry(sharedRegistry).COMPLIANCE_ROLE();

        vm.startBroadcast(privateKey);
        TrexModularCompliance complianceImpl = new TrexModularCompliance();
        bytes memory initData = abi.encodeCall(
            TrexModularCompliance.initialize,
            (superAdmin, governanceAgent, sharedRegistry)
        );
        modularCompliance =
            TrexModularCompliance(address(new ERC1967Proxy(address(complianceImpl), initData)));

        token = new TrexToken(
            name,
            symbol,
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(modularCompliance),
            maxSupply
        );
        modularCompliance.bindToken(address(token));
        vm.stopBroadcast();

        _writeArtifact(
            block.chainid,
            sharedRegistry,
            address(modularCompliance),
            address(token),
            name,
            symbol
        );

        emit AdditionalTrexTokenDeployment(
            sharedRegistry, address(modularCompliance), address(token), name, symbol
        );
    }

    function _writeArtifact(
        uint256 chainId,
        address identityRegistry,
        address modularCompliance,
        address token,
        string memory name,
        string memory symbol
    ) private {
        string memory key = "deployment";
        vm.serializeString(key, "profile", "trex-additional-token");
        vm.serializeString(key, "blockchainMode", "trex");
        vm.serializeUint(key, "chainId", chainId);
        vm.serializeString(key, "tokenName", name);
        vm.serializeString(key, "tokenSymbol", symbol);
        vm.serializeAddress(key, "identityRegistry", identityRegistry);
        vm.serializeAddress(key, "modularCompliance", modularCompliance);
        string memory json = vm.serializeAddress(key, "token", token);
        vm.writeJson(
            json,
            string.concat(
                "deployments/",
                Strings.toString(chainId),
                "-",
                symbol,
                ".json"
            )
        );
    }
}
