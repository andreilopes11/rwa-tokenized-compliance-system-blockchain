// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IdentityRegistry} from "../../src/legacy/identity/IdentityRegistry.sol";
import {PermissionedToken} from "../../src/legacy/token/PermissionedToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @notice Security checklist tests — see _docs/contracts-erc3643.md §5
contract ComplianceSecurityTest {
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

    function testSecurity_UnregisteredRecipientCannotReceiveTransfer() public {
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

    function testSecurity_RevokedInvestorCannotTransfer() public {
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

    function testSecurity_PauseBlocksTransfers() public {
        _approve(alice, aliceHash);
        _approve(bob, bobHash);
        token.mint(alice, 10 ether);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1 ether);
    }

    function testSecurity_NonOwnerCannotAddIdentity() public {
        vm.prank(mallory);
        vm.expectRevert();
        registry.addIdentity(alice, aliceHash);
    }

    function _approve(address wallet, bytes32 identityHash) private {
        registry.addIdentity(wallet, identityHash);
    }
}
