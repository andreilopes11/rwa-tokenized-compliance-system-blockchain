// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract TrexComplianceSecurityTest {
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

        _register(alice, "alice-doc");
        _register(bob, "bob-doc");

        vm.prank(lifecycleAgent);
        token.mint(alice, 100 ether);
    }

    function testSecurity_UnauthorizedRoleCannotCallGovernance() public {
        vm.prank(complianceAgent);
        vm.expectRevert();
        token.pause();
    }

    function testSecurity_UnauthorizedRoleCannotCallComplianceIdentityFunctions() public {
        vm.prank(governanceAgent);
        vm.expectRevert();
        registry.registerIdentity(mallory, keccak256("mallory-doc"));
    }

    function testSecurity_RevokedIdentityCannotSendOrReceiveImmediately() public {
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

    function testSecurity_PausedTokenRevertsAllTransferPaths() public {
        vm.prank(governanceAgent);
        token.pause();

        vm.prank(alice);
        vm.expectRevert(TrexToken.TokenPaused.selector);
        token.transfer(bob, 1 ether);

        vm.prank(alice);
        token.approve(transferManagerAgent, 1 ether);
        vm.prank(transferManagerAgent);
        vm.expectRevert(TrexToken.TokenPaused.selector);
        token.transferFrom(alice, bob, 1 ether);
    }

    function testSecurity_DuplicateIdentityRegistrationIsDeterministic() public {
        vm.prank(complianceAgent);
        vm.expectRevert(
            abi.encodeWithSelector(
                TrexIdentityRegistry.IdentityAlreadyRegistered.selector,
                alice
            )
        );
        registry.registerIdentity(alice, keccak256("alice-doc"));
    }

    function testSecurityFuzz_NoStateMutationWhenComplianceCheckFails(
        uint96 amount
    ) public {
        uint256 boundedAmount = uint256(amount % 10 ether) + 1;

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 malloryBefore = token.balanceOf(mallory);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                TrexToken.NonCompliantRecipient.selector,
                mallory
            )
        );
        token.transfer(mallory, boundedAmount);

        assert(token.balanceOf(alice) == aliceBefore);
        assert(token.balanceOf(mallory) == malloryBefore);
    }

    function _register(address wallet, string memory seed) private {
        vm.prank(complianceAgent);
        registry.registerIdentity(wallet, keccak256(bytes(seed)));
    }
}
