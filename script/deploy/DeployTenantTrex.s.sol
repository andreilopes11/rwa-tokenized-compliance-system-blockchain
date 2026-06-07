// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Vm} from "../../utils/foundry/Vm.sol";
import {TenantTrexLib} from "./TenantTrexLib.sol";

/// @notice Production per-tenant T-REX deployment. Reads agent addresses (Safe / HSM-KMS
///         principals) from the environment, deploys the full stack with the TimelockController
///         as the sole upgrade authority, and writes an auditable JSON artifact listing every
///         address and role assignment.
///
/// Required env: PRIVATE_KEY, GOVERNANCE_SAFE, COMPLIANCE_AGENT, LIFECYCLE_AGENT,
///   TRANSFER_MANAGER_AGENT, PAUSER, TENANT_TREASURY, FORCE_SYNC_OWNER_1..3.
/// Optional env (with defaults): TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, MAX_BALANCE,
///   MAX_HOLDERS, REQUIRED_TIER, TIMELOCK_MIN_DELAY (default 24h), FORCE_SYNC_THRESHOLD (2).
contract DeployTenantTrex {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (TenantTrexLib.Deployment memory deployment) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        address[] memory forceSyncOwners = new address[](3);
        forceSyncOwners[0] = vm.envAddress("FORCE_SYNC_OWNER_1");
        forceSyncOwners[1] = vm.envAddress("FORCE_SYNC_OWNER_2");
        forceSyncOwners[2] = vm.envAddress("FORCE_SYNC_OWNER_3");

        TenantTrexLib.Config memory cfg = TenantTrexLib.Config({
            deployer: vm.addr(privateKey),
            governanceSafe: vm.envAddress("GOVERNANCE_SAFE"),
            compliancePrincipal: vm.envAddress("COMPLIANCE_AGENT"),
            lifecycleAgent: vm.envAddress("LIFECYCLE_AGENT"),
            transferManager: vm.envAddress("TRANSFER_MANAGER_AGENT"),
            pauser: vm.envAddress("PAUSER"),
            tenantTreasury: vm.envAddress("TENANT_TREASURY"),
            tokenName: vm.envString("TOKEN_NAME"),
            tokenSymbol: vm.envString("TOKEN_SYMBOL"),
            maxSupply: vm.envOr("MAX_SUPPLY", uint256(0)),
            maxBalancePerHolder: vm.envOr("MAX_BALANCE", uint256(0)),
            maxHolders: vm.envOr("MAX_HOLDERS", uint256(0)),
            requiredSuitabilityTier: uint8(vm.envOr("REQUIRED_TIER", uint256(0))),
            timelockMinDelay: vm.envOr("TIMELOCK_MIN_DELAY", uint256(86400)),
            forceSyncOwners: forceSyncOwners,
            forceSyncThreshold: vm.envOr("FORCE_SYNC_THRESHOLD", uint256(2)),
            distributionMerkleRoot: bytes32(0),
            distributionClaimDeadline: uint64(block.timestamp + 90 days)
        });

        vm.startBroadcast(privateKey);
        deployment = TenantTrexLib.deploy(cfg);
        vm.stopBroadcast();

        _writeArtifact(deployment, cfg);
    }

    function _writeArtifact(TenantTrexLib.Deployment memory d, TenantTrexLib.Config memory cfg)
        private
    {
        string memory key = "deployment";
        vm.serializeString(key, "profile", "tenant-trex");
        vm.serializeUint(key, "chainId", block.chainid);
        vm.serializeUint(key, "timelockMinDelay", cfg.timelockMinDelay);
        vm.serializeUint(key, "maxSupply", cfg.maxSupply);

        // Contract addresses.
        vm.serializeAddress(key, "claimTopicsRegistry", d.claimTopicsRegistry);
        vm.serializeAddress(key, "trustedIssuersRegistry", d.trustedIssuersRegistry);
        vm.serializeAddress(key, "identityRegistryStorage", d.identityRegistryStorage);
        vm.serializeAddress(key, "identityRegistry", d.identityRegistry);
        vm.serializeAddress(key, "modularComplianceImpl", d.modularComplianceImpl);
        vm.serializeAddress(key, "modularCompliance", d.modularCompliance);
        vm.serializeAddress(key, "token", d.token);
        vm.serializeAddress(key, "timelock", d.timelock);
        vm.serializeAddress(key, "forceSyncGovernor", d.forceSyncGovernor);
        vm.serializeAddress(key, "holderSnapshotAnchor", d.holderSnapshotAnchor);
        vm.serializeAddress(key, "merkleDistributor", d.merkleDistributor);
        vm.serializeAddress(key, "pauseModule", d.pauseModule);
        vm.serializeAddress(key, "maxBalanceModule", d.maxBalanceModule);
        vm.serializeAddress(key, "maxHoldersModule", d.maxHoldersModule);
        vm.serializeAddress(key, "jurisdictionModule", d.jurisdictionModule);
        vm.serializeAddress(key, "suitabilityModule", d.suitabilityModule);

        // Role assignments.
        vm.serializeAddress(key, "role_superAdmin_governanceSafe", cfg.governanceSafe);
        vm.serializeAddress(key, "role_complianceAgent", cfg.compliancePrincipal);
        vm.serializeAddress(key, "role_lifecycleAgent", cfg.lifecycleAgent);
        vm.serializeAddress(key, "role_transferManager", cfg.transferManager);
        vm.serializeAddress(key, "role_pauser", cfg.pauser);
        string memory json =
            vm.serializeAddress(key, "role_upgrader_timelock", d.timelock);

        vm.writeJson(json, string.concat("deployments/", Strings.toString(block.chainid), "-tenant.json"));
    }
}
