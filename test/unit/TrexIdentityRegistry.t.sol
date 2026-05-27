// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract TrexIdentityRegistryTest {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TrexIdentityRegistry private registry;

    address private superAdmin = address(this);
    address private complianceAgent = address(0xC011);
    address private outsider = address(0xBEEF);
    address private alice = address(0xA11CE);
    bytes32 private aliceHash = keccak256("alice-doc-ref");

    function setUp() public {
        registry = new TrexIdentityRegistry(superAdmin, complianceAgent);
    }

    function testComplianceAgentCanRegisterIdentity() public {
        vm.prank(complianceAgent);
        registry.registerIdentity(alice, aliceHash);

        assert(registry.isVerified(alice));
    }

    function testNonComplianceAgentCannotRegisterOrRemove() public {
        vm.prank(outsider);
        vm.expectRevert();
        registry.registerIdentity(alice, aliceHash);

        vm.prank(outsider);
        vm.expectRevert();
        registry.removeIdentity(alice);
    }

    function testDuplicateRegistrationIsDeterministic() public {
        vm.prank(complianceAgent);
        registry.registerIdentity(alice, aliceHash);

        vm.prank(complianceAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                TrexIdentityRegistry.IdentityAlreadyRegistered.selector,
                alice
            )
        );
        registry.registerIdentity(alice, aliceHash);
    }

    function testRemovingUnknownIdentityRevertsDeterministically() public {
        vm.prank(complianceAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                TrexIdentityRegistry.IdentityNotRegistered.selector,
                alice
            )
        );
        registry.removeIdentity(alice);
    }

    function testRevocationImmediatelyInvalidatesIdentity() public {
        vm.prank(complianceAgent);
        registry.registerIdentity(alice, aliceHash);
        assert(registry.isVerified(alice));

        vm.prank(complianceAgent);
        registry.removeIdentity(alice);
        assert(!registry.isVerified(alice));
    }
}
