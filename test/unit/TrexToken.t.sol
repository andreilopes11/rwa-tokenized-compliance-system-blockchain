// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract TrexTokenTest {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TrexIdentityRegistry private registry;
    TrexModularCompliance private modularCompliance;
    TrexToken private token;

    address private superAdmin = address(this);
    address private governanceAgent = address(0x600D);
    address private complianceAgent = address(0xC011);
    address private lifecycleAgent = address(0x1FEC0);
    address private transferManagerAgent = address(0x7AA7);
    address private outsider = address(0xBEEF);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private mallory = address(0xBAD);

    function setUp() public {
        registry = new TrexIdentityRegistry(superAdmin, complianceAgent);
        modularCompliance =
            new TrexModularCompliance(superAdmin, governanceAgent, address(registry));
        token = new TrexToken(
            "VaultGuard Tokenized RWA",
            "VGRWA",
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(modularCompliance)
        );
    }

    function testOnlyLifecycleRoleCanMint() public {
        _register(alice, "alice-doc");

        vm.prank(outsider);
        vm.expectRevert();
        token.mint(alice, 1 ether);

        vm.prank(lifecycleAgent);
        token.mint(alice, 1 ether);
        assert(token.balanceOf(alice) == 1 ether);
    }

    function testPauseControlIsGovernanceOnly() public {
        vm.prank(outsider);
        vm.expectRevert();
        token.pause();

        vm.prank(governanceAgent);
        token.pause();
        assert(token.paused());

        vm.prank(governanceAgent);
        token.unpause();
        assert(!token.paused());
    }

    function testRevokedIdentityCannotSendOrReceive() public {
        _register(alice, "alice-doc");
        _register(bob, "bob-doc");

        vm.prank(lifecycleAgent);
        token.mint(alice, 10 ether);

        vm.prank(complianceAgent);
        registry.removeIdentity(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantSender.selector, alice)
        );
        token.transfer(bob, 1 ether);

        vm.prank(complianceAgent);
        registry.registerIdentity(alice, keccak256("alice-doc-2"));

        vm.prank(complianceAgent);
        registry.removeIdentity(bob);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantRecipient.selector, bob)
        );
        token.transfer(bob, 1 ether);
    }

    function testPausedTokenRevertsAllTransferPaths() public {
        _register(alice, "alice-doc");
        _register(bob, "bob-doc");

        vm.prank(lifecycleAgent);
        token.mint(alice, 10 ether);

        vm.prank(governanceAgent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(TrexToken.TokenPaused.selector);
        token.transfer(bob, 1 ether);

        vm.prank(alice);
        token.approve(transferManagerAgent, 2 ether);

        vm.prank(transferManagerAgent);
        vm.expectRevert(TrexToken.TokenPaused.selector);
        token.transferFrom(alice, bob, 1 ether);
    }

    function testForceTransferIsTransferManagerOnly() public {
        _register(alice, "alice-doc");
        _register(bob, "bob-doc");

        vm.prank(lifecycleAgent);
        token.mint(alice, 10 ether);

        vm.prank(outsider);
        vm.expectRevert();
        token.forceTransfer(alice, bob, 1 ether);

        vm.prank(transferManagerAgent);
        token.forceTransfer(alice, bob, 1 ether);
        assert(token.balanceOf(alice) == 9 ether);
        assert(token.balanceOf(bob) == 1 ether);
    }

    function _register(address wallet, string memory seed) private {
        vm.prank(complianceAgent);
        registry.registerIdentity(wallet, keccak256(bytes(seed)));
    }
}
