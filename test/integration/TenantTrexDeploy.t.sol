// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TenantTrexLib} from "../../script/deploy/TenantTrexLib.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {JurisdictionAllowModule} from "../../src/trex/modules/JurisdictionAllowModule.sol";
import {SuitabilityTierModule} from "../../src/trex/modules/SuitabilityTierModule.sol";
import {PauseModule} from "../../src/trex/modules/PauseModule.sol";
import {MaxHoldersModule} from "../../src/trex/modules/MaxHoldersModule.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract TenantTrexDeployTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant ADMIN = 0x00;

    address private governanceSafe = address(0x5AFE);
    address private compliancePrincipal = address(0xC011);
    address private lifecycleAgent = address(0x1FEC0);
    address private transferManager = address(0x7AA7);
    address private pauser = address(0xBA17);
    address private treasury = address(0x77EA);

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private carol = address(0xCA0A);

    TenantTrexLib.Deployment private d;
    TrexToken private token;
    TrexModularCompliance private compliance;
    TrexIdentityRegistry private registry;

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = address(0xF00D1);
        owners[1] = address(0xF00D2);
        owners[2] = address(0xF00D3);

        TenantTrexLib.Config memory cfg = TenantTrexLib.Config({
            deployer: address(this),
            governanceSafe: governanceSafe,
            compliancePrincipal: compliancePrincipal,
            lifecycleAgent: lifecycleAgent,
            transferManager: transferManager,
            pauser: pauser,
            tenantTreasury: treasury,
            tokenName: "VaultGuard Tokenized RWA",
            tokenSymbol: "VGRWA",
            maxSupply: 1_000_000 ether,
            maxBalancePerHolder: 500_000 ether,
            maxHolders: 100,
            requiredSuitabilityTier: 1,
            timelockMinDelay: 86_400,
            forceSyncOwners: owners,
            forceSyncThreshold: 2,
            distributionMerkleRoot: bytes32(0),
            distributionClaimDeadline: uint64(block.timestamp + 30 days)
        });

        d = TenantTrexLib.deploy(cfg);
        token = TrexToken(d.token);
        compliance = TrexModularCompliance(d.modularCompliance);
        registry = TrexIdentityRegistry(d.identityRegistry);
    }

    // ----- Role assignment acceptance -----

    function testDeploy_RolesAssignedAndDeployerRenounced() public view {
        assert(token.hasRole(ADMIN, governanceSafe));
        assert(token.hasRole(token.GOVERNANCE_ROLE(), pauser));
        assert(token.hasRole(token.LIFECYCLE_ROLE(), lifecycleAgent));
        assert(token.hasRole(token.TRANSFER_MANAGER_ROLE(), transferManager));

        assert(compliance.hasRole(compliance.UPGRADER_ROLE(), d.timelock));
        assert(compliance.hasRole(compliance.GOVERNANCE_ROLE(), pauser));
        assert(compliance.hasRole(ADMIN, governanceSafe));
        assert(!compliance.hasRole(ADMIN, address(this)));
        assert(!compliance.hasRole(compliance.GOVERNANCE_ROLE(), address(this)));

        assert(registry.hasRole(registry.COMPLIANCE_ROLE(), compliancePrincipal));
        assert(registry.hasRole(registry.COMPLIANCE_ROLE(), d.forceSyncGovernor));
        assert(registry.hasRole(ADMIN, governanceSafe));
        assert(!registry.hasRole(ADMIN, address(this)));
    }

    function testDeploy_AllFiveModulesBound() public view {
        assert(compliance.getModules().length == 5);
        assert(compliance.moduleBound(d.pauseModule));
        assert(compliance.moduleBound(d.maxBalanceModule));
        assert(compliance.moduleBound(d.maxHoldersModule));
        assert(compliance.moduleBound(d.jurisdictionModule));
        assert(compliance.moduleBound(d.suitabilityModule));
    }

    // ----- End-to-end happy path -----

    function testE2E_OnboardAndMintAndTransfer() public {
        _onboard(alice, 1, 1);
        _onboard(bob, 1, 1);

        vm.prank(lifecycleAgent);
        token.mint(alice, 1000 ether);
        assert(token.balanceOf(alice) == 1000 ether);

        vm.prank(alice);
        token.transfer(bob, 400 ether);
        assert(token.balanceOf(bob) == 400 ether);
        assert(token.balanceOf(alice) == 600 ether);
    }

    // ----- Module gating (each module blocks via TransferNotCompliant) -----

    function testModule_JurisdictionBlocksDisallowedCountry() public {
        // country 2 is never allow-listed.
        vm.prank(compliancePrincipal);
        registry.registerIdentity(bob, keccak256("bob"), 2);
        vm.prank(compliancePrincipal);
        SuitabilityTierModule(d.suitabilityModule).setInvestorTier(bob, 1);

        vm.prank(lifecycleAgent);
        vm.expectRevert(TrexToken.TransferNotCompliant.selector);
        token.mint(bob, 1 ether);
    }

    function testModule_SuitabilityTierBlocksLowTier() public {
        vm.prank(compliancePrincipal);
        registry.registerIdentity(carol, keccak256("carol"), 1);
        vm.prank(governanceSafe);
        JurisdictionAllowModule(d.jurisdictionModule).setJurisdiction(1, true);
        // tier left at 0 (< required 1)

        vm.prank(lifecycleAgent);
        vm.expectRevert(TrexToken.TransferNotCompliant.selector);
        token.mint(carol, 1 ether);
    }

    function testModule_PauseModuleBlocksTransfers() public {
        _onboard(alice, 1, 1);

        vm.prank(pauser);
        PauseModule(d.pauseModule).setPaused(true);

        vm.prank(lifecycleAgent);
        vm.expectRevert(TrexToken.TransferNotCompliant.selector);
        token.mint(alice, 1 ether);
    }

    function testModule_MaxHoldersBlocksExtraHolder() public {
        _onboard(alice, 1, 1);
        _onboard(bob, 1, 1);

        vm.prank(governanceSafe);
        MaxHoldersModule(d.maxHoldersModule).setMaxHolders(1);

        vm.prank(lifecycleAgent);
        token.mint(alice, 10 ether);

        vm.prank(lifecycleAgent);
        vm.expectRevert(TrexToken.TransferNotCompliant.selector);
        token.mint(bob, 1 ether);
    }

    function testModule_MaxBalanceBlocksOversizedHolding() public {
        _onboard(alice, 1, 1);

        vm.prank(lifecycleAgent);
        vm.expectRevert(TrexToken.TransferNotCompliant.selector);
        token.mint(alice, 600_000 ether); // > maxBalancePerHolder (500k)
    }

    // ----- helpers -----

    function _onboard(address wallet, uint16 country, uint8 tier) private {
        vm.prank(compliancePrincipal);
        registry.registerIdentity(wallet, keccak256(abi.encodePacked(wallet)), country);
        vm.prank(governanceSafe);
        JurisdictionAllowModule(d.jurisdictionModule).setJurisdiction(country, true);
        vm.prank(compliancePrincipal);
        SuitabilityTierModule(d.suitabilityModule).setInvestorTier(wallet, tier);
    }
}
