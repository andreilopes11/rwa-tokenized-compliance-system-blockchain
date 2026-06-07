// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {PauseModule} from "../../src/trex/modules/PauseModule.sol";
import {TrexDeploy} from "../helpers/TrexDeploy.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @dev Binds the test contract as the token (token == address(this)) so the bookkeeping
///      hooks (transferred/created/destroyed) and onlyToken guard can be exercised directly.
contract ModularComplianceUnitTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant ADMIN = 0x00;

    TrexIdentityRegistry private registry;
    TrexModularCompliance private compliance;

    address private complianceAgent = address(0xC011);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private outsider = address(0xDEAD);

    function setUp() public {
        registry = new TrexIdentityRegistry(address(this), complianceAgent);
        compliance = TrexDeploy.deployCompliance(address(this), address(this), address(registry));
        compliance.bindToken(address(this));

        vm.prank(complianceAgent);
        registry.registerIdentity(alice, keccak256("a"));
        vm.prank(complianceAgent);
        registry.registerIdentity(bob, keccak256("b"));
    }

    function testBindToken_CannotRebind() public {
        vm.expectRevert(TrexModularCompliance.TokenAlreadyBound.selector);
        compliance.bindToken(address(0xABCD));
    }

    function testModuleManagement_AddRemoveAndErrors() public {
        PauseModule pm = new PauseModule(address(compliance), address(this));
        compliance.addModule(address(pm));
        assert(compliance.getModules().length == 1);
        assert(compliance.moduleBound(address(pm)));

        vm.expectRevert(
            abi.encodeWithSelector(
                TrexModularCompliance.ModuleAlreadyBound.selector, address(pm)
            )
        );
        compliance.addModule(address(pm));

        vm.expectRevert(TrexModularCompliance.InvalidModule.selector);
        compliance.addModule(address(0));

        compliance.removeModule(address(pm));
        assert(compliance.getModules().length == 0);

        vm.expectRevert(
            abi.encodeWithSelector(TrexModularCompliance.ModuleNotBound.selector, address(pm))
        );
        compliance.removeModule(address(pm));
    }

    function testCanTransfer_BuiltInGates() public {
        assert(compliance.canTransfer(alice, bob, 1));

        compliance.setLimits(5);
        assert(!compliance.canTransfer(alice, bob, 6));
        assert(compliance.canTransfer(alice, bob, 5));
        compliance.setLimits(0);

        compliance.setPaused(true);
        assert(!compliance.canTransfer(alice, bob, 1));
        compliance.setPaused(false);

        assert(!compliance.canTransfer(alice, outsider, 1)); // outsider not verified
        assert(compliance.isWalletVerified(alice));
    }

    function testHooks_OnlyTokenMayCall() public {
        // address(this) is the bound token, so these succeed (no modules => no-op loops).
        compliance.created(alice, 1);
        compliance.transferred(alice, bob, 1);
        compliance.destroyed(alice, 1);

        vm.prank(outsider);
        vm.expectRevert(TrexModularCompliance.NotBoundToken.selector);
        compliance.transferred(alice, bob, 1);
    }

    function testInitialize_CannotReinitialize() public {
        vm.expectRevert();
        compliance.initialize(address(this), address(this), address(registry));
    }
}
