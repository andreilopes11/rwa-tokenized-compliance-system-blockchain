// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {ClaimTopicsRegistry} from "../../src/trex/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/trex/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/trex/registry/IdentityRegistryStorage.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract IdentityRegistryExtraTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private superAdmin = address(this);
    address private complianceAgent = address(0xC011);
    address private alice = address(0xA11CE);

    TrexIdentityRegistry private registry;
    IdentityRegistryStorage private idStorage;

    function setUp() public {
        registry = new TrexIdentityRegistry(superAdmin, complianceAgent);
        ClaimTopicsRegistry claimTopics = new ClaimTopicsRegistry(superAdmin);
        TrustedIssuersRegistry trustedIssuers = new TrustedIssuersRegistry(superAdmin);
        idStorage = new IdentityRegistryStorage(superAdmin);

        idStorage.bindIdentityRegistry(address(registry));
        registry.bindRegistries(
            address(claimTopics), address(trustedIssuers), address(idStorage)
        );
    }

    function testRegisterWithCountryMirrorsToStorage() public {
        vm.prank(complianceAgent);
        registry.registerIdentity(alice, keccak256("a"), 840);

        assert(registry.isVerified(alice));
        assert(registry.getIdentity(alice).referenceHash == keccak256("a"));
        assert(idStorage.isVerified(alice));
        assert(idStorage.identityCountry(alice) == 840);

        vm.prank(complianceAgent);
        registry.removeIdentity(alice);
        assert(!idStorage.isVerified(alice));
    }

    function testRegisterRejectsInvalidInput() public {
        vm.prank(complianceAgent);
        vm.expectRevert(TrexIdentityRegistry.InvalidWallet.selector);
        registry.registerIdentity(address(0), keccak256("a"));

        vm.prank(complianceAgent);
        vm.expectRevert(TrexIdentityRegistry.InvalidReferenceHash.selector);
        registry.registerIdentity(alice, bytes32(0));
    }

    function testBindRegistriesIsAdminOnly() public {
        vm.prank(complianceAgent);
        vm.expectRevert();
        registry.bindRegistries(address(1), address(2), address(3));
    }
}
