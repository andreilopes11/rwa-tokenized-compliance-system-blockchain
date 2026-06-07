// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {ForceSyncGovernor} from "../../src/trex/governance/ForceSyncGovernor.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract ForceSyncGovernorTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TrexIdentityRegistry private registry;
    ForceSyncGovernor private governor;

    address private superAdmin = address(this);
    address private complianceAgent = address(0xC011);
    address private owner1 = address(0xF00D1);
    address private owner2 = address(0xF00D2);
    address private owner3 = address(0xF00D3);
    address private outsider = address(0xDEAD);
    address private wallet = address(0xA11CE);
    bytes32 private refHash = keccak256("alice-doc");

    function setUp() public {
        registry = new TrexIdentityRegistry(superAdmin, complianceAgent);
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        governor = new ForceSyncGovernor(owners, 2, address(registry));
        // Governor must hold COMPLIANCE_ROLE to write identities on-chain.
        registry.grantRole(registry.COMPLIANCE_ROLE(), address(governor));
    }

    function testForceSync_RequiresTwoDistinctSigners() public {
        vm.prank(owner1);
        governor.forceSyncOnChain(wallet, refHash, 1);
        // After a single approval the identity is NOT yet synced.
        assert(!registry.isVerified(wallet));

        vm.prank(owner2);
        governor.forceSyncOnChain(wallet, refHash, 1);
        // Second distinct owner triggers execution.
        assert(registry.isVerified(wallet));
    }

    function testForceSync_SameOwnerCannotDoubleApprove() public {
        vm.prank(owner1);
        governor.forceSyncOnChain(wallet, refHash, 1);

        vm.prank(owner1);
        vm.expectRevert(ForceSyncGovernor.DuplicateApproval.selector);
        governor.forceSyncOnChain(wallet, refHash, 1);

        assert(!registry.isVerified(wallet));
    }

    function testForceSync_NonOwnerCannotApprove() public {
        vm.prank(outsider);
        vm.expectRevert(ForceSyncGovernor.NotOwner.selector);
        governor.forceSyncOnChain(wallet, refHash, 1);
    }

    function testForceSync_CannotReexecuteCompletedOperation() public {
        vm.prank(owner1);
        governor.forceSyncOnChain(wallet, refHash, 1);
        vm.prank(owner2);
        governor.forceSyncOnChain(wallet, refHash, 1);

        vm.prank(owner3);
        vm.expectRevert(ForceSyncGovernor.AlreadyExecuted.selector);
        governor.forceSyncOnChain(wallet, refHash, 1);
    }

    function testForceSync_ConstructorRejectsBadThreshold() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        vm.expectRevert(ForceSyncGovernor.InvalidThreshold.selector);
        new ForceSyncGovernor(owners, 1, address(registry));
    }

    function testForceSync_ConstructorGuardsAndOwners() public {
        assert(governor.getOwners().length == 3);
        assert(governor.threshold() == 2);

        address[] memory two = new address[](2);
        two[0] = owner1;
        two[1] = owner2;
        vm.expectRevert(ForceSyncGovernor.InvalidTarget.selector);
        new ForceSyncGovernor(two, 2, address(0));

        address[] memory one = new address[](1);
        one[0] = owner1;
        vm.expectRevert(ForceSyncGovernor.InvalidOwners.selector);
        new ForceSyncGovernor(one, 2, address(registry));

        address[] memory dup = new address[](2);
        dup[0] = owner1;
        dup[1] = owner1;
        vm.expectRevert(ForceSyncGovernor.InvalidOwners.selector);
        new ForceSyncGovernor(dup, 2, address(registry));
    }
}
