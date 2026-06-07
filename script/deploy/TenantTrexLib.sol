// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {ClaimTopicsRegistry} from "../../src/trex/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/trex/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/trex/registry/IdentityRegistryStorage.sol";
import {PauseModule} from "../../src/trex/modules/PauseModule.sol";
import {MaxBalanceModule} from "../../src/trex/modules/MaxBalanceModule.sol";
import {MaxHoldersModule} from "../../src/trex/modules/MaxHoldersModule.sol";
import {JurisdictionAllowModule} from "../../src/trex/modules/JurisdictionAllowModule.sol";
import {SuitabilityTierModule} from "../../src/trex/modules/SuitabilityTierModule.sol";
import {ForceSyncGovernor} from "../../src/trex/governance/ForceSyncGovernor.sol";
import {HolderSnapshotAnchor} from "../../src/trex/governance/HolderSnapshotAnchor.sol";
import {MerkleDistributor} from "../../src/trex/distribution/MerkleDistributor.sol";

/// @notice Reusable per-tenant T-REX stack deployment + role wiring. Implemented as an
///         inlinable library so it can be exercised both by the broadcast script and by
///         tests against the real wiring. `cfg.deployer` is the temporary admin that
///         performs configuration and then hands every role to the production principals.
library TenantTrexLib {
    bytes32 internal constant ADMIN = 0x00; // DEFAULT_ADMIN_ROLE

    struct Config {
        address deployer; // temporary admin = tx sender (EOA under broadcast, test contract otherwise)
        address governanceSafe; // SUPER_ADMIN multisig: DEFAULT_ADMIN + registry/snapshot owner + timelock proposer
        address compliancePrincipal; // COMPLIANCE_ROLE (HSM/KMS) + suitability admin
        address lifecycleAgent; // LIFECYCLE_ROLE (mint)
        address transferManager; // TRANSFER_MANAGER_ROLE (forceTransfer)
        address pauser; // GOVERNANCE_ROLE (pause/limits/modules) - separate from the upgrade key
        address tenantTreasury; // MerkleDistributor reclaim target
        string tokenName;
        string tokenSymbol;
        uint256 maxSupply;
        uint256 maxBalancePerHolder;
        uint256 maxHolders;
        uint8 requiredSuitabilityTier;
        uint256 timelockMinDelay; // >= 24h in production
        address[] forceSyncOwners;
        uint256 forceSyncThreshold;
        bytes32 distributionMerkleRoot;
        uint64 distributionClaimDeadline;
    }

    struct Deployment {
        address claimTopicsRegistry;
        address trustedIssuersRegistry;
        address identityRegistryStorage;
        address identityRegistry;
        address modularComplianceImpl;
        address modularCompliance;
        address token;
        address timelock;
        address forceSyncGovernor;
        address holderSnapshotAnchor;
        address merkleDistributor;
        address pauseModule;
        address maxBalanceModule;
        address maxHoldersModule;
        address jurisdictionModule;
        address suitabilityModule;
    }

    error OverlappingRoleAssignments();
    error InvalidRoleAddress();

    function deploy(Config memory cfg) internal returns (Deployment memory d) {
        _assertSeparationOfDuties(cfg);
        _deployRegistries(cfg, d);
        _deployComplianceAndToken(cfg, d);
        _deployModules(cfg, d);
        _deployGovernance(cfg, d);
        _handoff(cfg, d);
    }

    function _deployRegistries(Config memory cfg, Deployment memory d) private {
        ClaimTopicsRegistry claimTopics = new ClaimTopicsRegistry(cfg.governanceSafe);
        TrustedIssuersRegistry trustedIssuers = new TrustedIssuersRegistry(cfg.governanceSafe);
        IdentityRegistryStorage idStorage = new IdentityRegistryStorage(cfg.deployer);
        TrexIdentityRegistry identityRegistry =
            new TrexIdentityRegistry(cfg.deployer, cfg.compliancePrincipal);

        idStorage.bindIdentityRegistry(address(identityRegistry));
        identityRegistry.bindRegistries(
            address(claimTopics), address(trustedIssuers), address(idStorage)
        );

        d.claimTopicsRegistry = address(claimTopics);
        d.trustedIssuersRegistry = address(trustedIssuers);
        d.identityRegistryStorage = address(idStorage);
        d.identityRegistry = address(identityRegistry);
    }

    function _deployComplianceAndToken(Config memory cfg, Deployment memory d) private {
        TrexModularCompliance complianceImpl = new TrexModularCompliance();
        bytes memory initData = abi.encodeCall(
            TrexModularCompliance.initialize,
            (cfg.deployer, cfg.deployer, d.identityRegistry)
        );
        TrexModularCompliance compliance =
            TrexModularCompliance(address(new ERC1967Proxy(address(complianceImpl), initData)));

        TrexToken token = new TrexToken(
            cfg.tokenName,
            cfg.tokenSymbol,
            cfg.governanceSafe,
            cfg.pauser,
            cfg.lifecycleAgent,
            cfg.transferManager,
            address(compliance),
            cfg.maxSupply
        );
        compliance.bindToken(address(token));

        d.modularComplianceImpl = address(complianceImpl);
        d.modularCompliance = address(compliance);
        d.token = address(token);
    }

    function _deployModules(Config memory cfg, Deployment memory d) private {
        TrexModularCompliance compliance = TrexModularCompliance(d.modularCompliance);

        PauseModule pauseModule = new PauseModule(d.modularCompliance, cfg.pauser);
        MaxBalanceModule maxBalance =
            new MaxBalanceModule(d.modularCompliance, cfg.deployer, cfg.maxBalancePerHolder);
        maxBalance.setToken(d.token);
        maxBalance.transferOwnership(cfg.governanceSafe);
        MaxHoldersModule maxHolders =
            new MaxHoldersModule(d.modularCompliance, cfg.deployer, cfg.maxHolders);
        maxHolders.setToken(d.token);
        maxHolders.transferOwnership(cfg.governanceSafe);
        JurisdictionAllowModule jurisdiction = new JurisdictionAllowModule(
            d.modularCompliance, cfg.governanceSafe, d.identityRegistryStorage
        );
        SuitabilityTierModule suitability = new SuitabilityTierModule(
            d.modularCompliance, cfg.compliancePrincipal, cfg.requiredSuitabilityTier
        );

        compliance.addModule(address(pauseModule));
        compliance.addModule(address(maxBalance));
        compliance.addModule(address(maxHolders));
        compliance.addModule(address(jurisdiction));
        compliance.addModule(address(suitability));

        d.pauseModule = address(pauseModule);
        d.maxBalanceModule = address(maxBalance);
        d.maxHoldersModule = address(maxHolders);
        d.jurisdictionModule = address(jurisdiction);
        d.suitabilityModule = address(suitability);
    }

    function _deployGovernance(Config memory cfg, Deployment memory d) private {
        TrexModularCompliance compliance = TrexModularCompliance(d.modularCompliance);
        TrexIdentityRegistry identityRegistry = TrexIdentityRegistry(d.identityRegistry);

        address[] memory proposers = new address[](1);
        proposers[0] = cfg.governanceSafe;
        address[] memory executors = new address[](1);
        executors[0] = cfg.governanceSafe;
        TimelockController timelock =
            new TimelockController(cfg.timelockMinDelay, proposers, executors, address(0));
        compliance.grantRole(compliance.UPGRADER_ROLE(), address(timelock));

        ForceSyncGovernor governor = new ForceSyncGovernor(
            cfg.forceSyncOwners, cfg.forceSyncThreshold, d.identityRegistry
        );
        identityRegistry.grantRole(identityRegistry.COMPLIANCE_ROLE(), address(governor));

        HolderSnapshotAnchor snapshot = new HolderSnapshotAnchor(cfg.governanceSafe);
        MerkleDistributor distributor = new MerkleDistributor(
            d.token,
            cfg.distributionMerkleRoot,
            cfg.distributionClaimDeadline,
            cfg.tenantTreasury,
            cfg.governanceSafe
        );

        d.timelock = address(timelock);
        d.forceSyncGovernor = address(governor);
        d.holderSnapshotAnchor = address(snapshot);
        d.merkleDistributor = address(distributor);
    }

    function _handoff(Config memory cfg, Deployment memory d) private {
        TrexIdentityRegistry identityRegistry = TrexIdentityRegistry(d.identityRegistry);
        IdentityRegistryStorage idStorage = IdentityRegistryStorage(d.identityRegistryStorage);
        TrexModularCompliance compliance = TrexModularCompliance(d.modularCompliance);

        identityRegistry.grantRole(ADMIN, cfg.governanceSafe);
        identityRegistry.renounceRole(ADMIN, cfg.deployer);

        idStorage.grantRole(ADMIN, cfg.governanceSafe);
        idStorage.renounceRole(ADMIN, cfg.deployer);

        compliance.grantRole(compliance.GOVERNANCE_ROLE(), cfg.pauser);
        compliance.grantRole(ADMIN, cfg.governanceSafe);
        compliance.renounceRole(compliance.GOVERNANCE_ROLE(), cfg.deployer);
        compliance.renounceRole(ADMIN, cfg.deployer);
    }

    function _assertSeparationOfDuties(Config memory cfg) private pure {
        if (
            cfg.governanceSafe == address(0) || cfg.compliancePrincipal == address(0)
                || cfg.lifecycleAgent == address(0) || cfg.transferManager == address(0)
                || cfg.pauser == address(0) || cfg.tenantTreasury == address(0)
        ) {
            revert InvalidRoleAddress();
        }
        address[5] memory privileged = [
            cfg.governanceSafe,
            cfg.compliancePrincipal,
            cfg.lifecycleAgent,
            cfg.transferManager,
            cfg.pauser
        ];
        for (uint256 i = 0; i < privileged.length; i++) {
            for (uint256 j = i + 1; j < privileged.length; j++) {
                if (privileged[i] == privileged[j]) revert OverlappingRoleAssignments();
            }
        }
    }
}
