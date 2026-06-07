// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ClaimTopicsRegistry} from "../../src/trex/registry/ClaimTopicsRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/trex/registry/TrustedIssuersRegistry.sol";
import {IdentityRegistryStorage} from "../../src/trex/registry/IdentityRegistryStorage.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract RegistriesTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private owner = address(this);
    address private outsider = address(0xDEAD);
    address private issuer = address(0x155E);
    address private registryAgent = address(0xAEED);
    address private wallet = address(0xA11CE);

    ClaimTopicsRegistry private claimTopics;
    TrustedIssuersRegistry private trustedIssuers;
    IdentityRegistryStorage private idStorage;

    function setUp() public {
        claimTopics = new ClaimTopicsRegistry(owner);
        trustedIssuers = new TrustedIssuersRegistry(owner);
        idStorage = new IdentityRegistryStorage(owner);
    }

    function testClaimTopics_AddRemoveAndDuplicate() public {
        claimTopics.addClaimTopic(1);
        claimTopics.addClaimTopic(2);
        assert(claimTopics.requiredTopicCount() == 2);
        assert(claimTopics.getClaimTopics()[0] == 1);

        vm.expectRevert(
            abi.encodeWithSelector(ClaimTopicsRegistry.TopicAlreadyExists.selector, uint256(1))
        );
        claimTopics.addClaimTopic(1);

        claimTopics.removeClaimTopic(1);
        assert(claimTopics.requiredTopicCount() == 1);

        vm.expectRevert(
            abi.encodeWithSelector(ClaimTopicsRegistry.TopicNotFound.selector, uint256(1))
        );
        claimTopics.removeClaimTopic(1);
    }

    function testClaimTopics_OnlyOwner() public {
        vm.prank(outsider);
        vm.expectRevert();
        claimTopics.addClaimTopic(7);
    }

    function testTrustedIssuers_AddHasTopicRemove() public {
        uint256[] memory topics = new uint256[](2);
        topics[0] = 1;
        topics[1] = 5;
        trustedIssuers.addTrustedIssuer(issuer, topics);

        assert(trustedIssuers.isTrustedIssuer(issuer));
        assert(trustedIssuers.hasClaimTopic(issuer, 5));
        assert(!trustedIssuers.hasClaimTopic(issuer, 9));
        assert(trustedIssuers.getTrustedIssuers().length == 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                TrustedIssuersRegistry.IssuerAlreadyTrusted.selector, issuer
            )
        );
        trustedIssuers.addTrustedIssuer(issuer, topics);

        trustedIssuers.removeTrustedIssuer(issuer);
        assert(!trustedIssuers.isTrustedIssuer(issuer));
        assert(!trustedIssuers.hasClaimTopic(issuer, 5));
    }

    function testTrustedIssuers_RejectsEmptyTopicsAndUnknownRemoval() public {
        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(TrustedIssuersRegistry.EmptyTopics.selector);
        trustedIssuers.addTrustedIssuer(issuer, empty);

        vm.expectRevert(
            abi.encodeWithSelector(TrustedIssuersRegistry.IssuerNotTrusted.selector, issuer)
        );
        trustedIssuers.removeTrustedIssuer(issuer);
    }

    function testIdentityStorage_OnlyBoundAgentCanWrite() public {
        vm.expectRevert();
        idStorage.storeIdentity(wallet, keccak256("ref"), 1);

        idStorage.bindIdentityRegistry(registryAgent);
        vm.prank(registryAgent);
        idStorage.storeIdentity(wallet, keccak256("ref"), 840);

        assert(idStorage.isVerified(wallet));
        assert(idStorage.identityCountry(wallet) == 840);

        vm.prank(registryAgent);
        idStorage.revokeIdentity(wallet);
        assert(!idStorage.isVerified(wallet));
    }

    function testIdentityStorage_RejectsInvalidInput() public {
        idStorage.bindIdentityRegistry(registryAgent);

        vm.prank(registryAgent);
        vm.expectRevert(IdentityRegistryStorage.InvalidReferenceHash.selector);
        idStorage.storeIdentity(wallet, bytes32(0), 1);

        vm.prank(registryAgent);
        vm.expectRevert(IdentityRegistryStorage.InvalidWallet.selector);
        idStorage.storeIdentity(address(0), keccak256("r"), 1);
    }

    function testIdentityStorage_UnbindAndGetStored() public {
        idStorage.bindIdentityRegistry(registryAgent);
        vm.prank(registryAgent);
        idStorage.storeIdentity(wallet, keccak256("ref"), 250);
        assert(idStorage.getStoredIdentity(wallet).country == 250);

        idStorage.unbindIdentityRegistry(registryAgent);
        vm.prank(registryAgent);
        vm.expectRevert();
        idStorage.storeIdentity(wallet, keccak256("ref2"), 1);
    }

    function testIdentityStorage_ConstructorRejectsZeroAdmin() public {
        vm.expectRevert(IdentityRegistryStorage.InvalidWallet.selector);
        new IdentityRegistryStorage(address(0));
    }
}
