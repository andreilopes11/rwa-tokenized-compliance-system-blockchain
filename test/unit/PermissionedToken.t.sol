// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";
import {PermissionedToken} from "../../src/token/PermissionedToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract PermissionedTokenTest {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IdentityRegistry private registry;
    PermissionedToken private token;

    address private owner = address(this);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private mallory = address(0xBAD);

    bytes32 private aliceHash = keccak256("alice-doc");
    bytes32 private bobHash = keccak256("bob-doc");

    function setUp() public {
        registry = new IdentityRegistry(owner);
        token = new PermissionedToken(
            "Tokenized RWA Compliance Share",
            "RWAC",
            address(registry),
            owner
        );
    }

    function testApprovedInvestorCanReceiveAndTransferTokens() public {
        _approve(alice, aliceHash);
        _approve(bob, bobHash);

        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.transfer(bob, 25 ether);

        assert(token.balanceOf(alice) == 75 ether);
        assert(token.balanceOf(bob) == 25 ether);
    }

    function testUnverifiedWalletCannotReceiveMintedTokens() public {
        _approve(alice, aliceHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionedToken.WalletNotVerified.selector,
                mallory
            )
        );
        token.mint(mallory, 1 ether);
    }

    function testTransferToUnverifiedWalletIsBlocked() public {
        _approve(alice, aliceHash);
        token.mint(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionedToken.WalletNotVerified.selector,
                mallory
            )
        );
        token.transfer(mallory, 1 ether);
    }

    function testRevokedInvestorCannotSendTokens() public {
        _approve(alice, aliceHash);
        _approve(bob, bobHash);
        token.mint(alice, 10 ether);
        registry.revokeIdentity(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionedToken.WalletNotVerified.selector,
                alice
            )
        );
        token.transfer(bob, 1 ether);
    }

    function testEmergencyPauseBlocksTransfers() public {
        _approve(alice, aliceHash);
        _approve(bob, bobHash);
        token.mint(alice, 10 ether);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1 ether);
    }

    function testTransferFromCannotBypassCompliance() public {
        _approve(alice, aliceHash);
        token.mint(alice, 10 ether);

        vm.prank(alice);
        token.approve(owner, 5 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionedToken.WalletNotVerified.selector,
                mallory
            )
        );
        token.transferFrom(alice, mallory, 1 ether);
    }

    function testBurnRequiresVerifiedHolder() public {
        _approve(alice, aliceHash);
        token.mint(alice, 10 ether);
        registry.revokeIdentity(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionedToken.WalletNotVerified.selector,
                alice
            )
        );
        token.burn(1 ether);
    }

    function _approve(address wallet, bytes32 identityHash) private {
        registry.addIdentity(wallet, identityHash);
    }
}
