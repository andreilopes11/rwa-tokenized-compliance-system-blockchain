// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {TrexDeploy} from "../helpers/TrexDeploy.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @notice Marketplace preferred mode: multiple tokens share one IdentityRegistry.
///         Visibility (PUBLIC/PRIVATE) stays off-chain — not asserted here.
contract SharedIdentityRegistryTest {
    Vm private constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TrexIdentityRegistry private sharedRegistry;
    TrexToken private tokenA;
    TrexToken private tokenB;

    address private superAdmin = address(this);
    address private governanceAgent = address(0x600D);
    address private complianceAgent = address(0xC011);
    address private lifecycleAgent = address(0x1FEC0);
    address private transferManagerAgent = address(0x7AA7);

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        sharedRegistry = new TrexIdentityRegistry(superAdmin, complianceAgent);

        TrexModularCompliance complianceA =
            TrexDeploy.deployCompliance(superAdmin, governanceAgent, address(sharedRegistry));
        TrexModularCompliance complianceB =
            TrexDeploy.deployCompliance(superAdmin, governanceAgent, address(sharedRegistry));

        tokenA = new TrexToken(
            "VaultGuard Asset A",
            "VGA",
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(complianceA),
            0
        );
        tokenB = new TrexToken(
            "VaultGuard Asset B",
            "VGB",
            superAdmin,
            governanceAgent,
            lifecycleAgent,
            transferManagerAgent,
            address(complianceB),
            0
        );

        complianceA.bindToken(address(tokenA));
        complianceB.bindToken(address(tokenB));
    }

    function testSharedIR_SingleRegistrationUnlocksBothTokens() public {
        vm.prank(complianceAgent);
        sharedRegistry.registerIdentity(alice, keccak256("alice-doc"));
        vm.prank(complianceAgent);
        sharedRegistry.registerIdentity(bob, keccak256("bob-doc"));

        vm.prank(lifecycleAgent);
        tokenA.mint(alice, 50 ether);
        vm.prank(lifecycleAgent);
        tokenB.mint(alice, 25 ether);

        vm.prank(alice);
        tokenA.transfer(bob, 10 ether);
        vm.prank(alice);
        tokenB.transfer(bob, 5 ether);

        assert(tokenA.balanceOf(bob) == 10 ether);
        assert(tokenB.balanceOf(bob) == 5 ether);
        assert(
            address(TrexModularCompliance(address(tokenA.modularCompliance())).identityRegistry())
                == address(sharedRegistry)
        );
        assert(
            address(TrexModularCompliance(address(tokenB.modularCompliance())).identityRegistry())
                == address(sharedRegistry)
        );
    }

    function testSharedIR_RevokeBlocksTransferOnBothTokens() public {
        vm.prank(complianceAgent);
        sharedRegistry.registerIdentity(alice, keccak256("alice-doc"));
        vm.prank(complianceAgent);
        sharedRegistry.registerIdentity(bob, keccak256("bob-doc"));

        vm.prank(lifecycleAgent);
        tokenA.mint(alice, 20 ether);
        vm.prank(lifecycleAgent);
        tokenB.mint(alice, 20 ether);

        vm.prank(complianceAgent);
        sharedRegistry.removeIdentity(alice);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantSender.selector, alice)
        );
        tokenA.transfer(bob, 1 ether);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantSender.selector, alice)
        );
        tokenB.transfer(bob, 1 ether);
    }

    function testSharedIR_UnregisteredCannotReceiveOnEitherToken() public {
        vm.prank(complianceAgent);
        sharedRegistry.registerIdentity(alice, keccak256("alice-doc"));

        vm.prank(lifecycleAgent);
        tokenA.mint(alice, 10 ether);

        address mallory = address(0xBAD);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantRecipient.selector, mallory)
        );
        tokenA.transfer(mallory, 1 ether);

        vm.prank(lifecycleAgent);
        vm.expectRevert(
            abi.encodeWithSelector(TrexToken.NonCompliantRecipient.selector, mallory)
        );
        tokenB.mint(mallory, 1 ether);
    }
}
