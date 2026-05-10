// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract IdentityRegistryTest {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IdentityRegistry private registry;

    address private owner = address(this);
    address private alice = address(0xA11CE);
    address private outsider = address(0xBEEF);
    bytes32 private aliceHash = keccak256("alice-doc");

    event IdentityAdded(
        address indexed wallet,
        bytes32 indexed identityHash,
        address indexed operator
    );

    function setUp() public {
        registry = new IdentityRegistry(owner);
    }

    function testOwnerCanApproveIdentity() public {
        vm.expectEmit(true, true, true, true);
        emit IdentityAdded(alice, aliceHash, owner);

        registry.addIdentity(alice, aliceHash);

        IdentityRegistry.Identity memory identity = registry.getIdentity(alice);
        assert(identity.verified);
        assert(identity.identityHash == aliceHash);
        assert(identity.approvedAt > 0);
        assert(identity.revokedAt == 0);
    }

    function testCannotApproveZeroAddressOrEmptyHash() public {
        vm.expectRevert(IdentityRegistry.InvalidWallet.selector);
        registry.addIdentity(address(0), aliceHash);

        vm.expectRevert(IdentityRegistry.InvalidIdentityHash.selector);
        registry.addIdentity(alice, bytes32(0));
    }

    function testCannotApproveWalletTwice() public {
        registry.addIdentity(alice, aliceHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRegistry.IdentityAlreadyVerified.selector,
                alice
            )
        );
        registry.addIdentity(alice, aliceHash);
    }

    function testRevocationMarksWalletAsUnverified() public {
        registry.addIdentity(alice, aliceHash);

        registry.revokeIdentity(alice);

        IdentityRegistry.Identity memory identity = registry.getIdentity(alice);
        assert(!identity.verified);
        assert(identity.revokedAt >= identity.approvedAt);
        assert(!registry.isVerified(alice));
    }

    function testCannotRevokeUnknownWallet() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IdentityRegistry.IdentityNotVerified.selector,
                outsider
            )
        );
        registry.revokeIdentity(outsider);
    }
}
