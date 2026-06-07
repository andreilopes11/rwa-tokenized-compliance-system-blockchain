// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MerkleDistributor} from "../../src/trex/distribution/MerkleDistributor.sol";
import {HolderSnapshotAnchor} from "../../src/trex/governance/HolderSnapshotAnchor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract PeripheryDistributionTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private owner = address(this);
    address private treasury = address(0x77EA);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private outsider = address(0xDEAD);

    MockERC20 private token;
    MerkleDistributor private distributor;
    bytes32 private root;
    uint256 private aliceAmount = 100 ether;
    uint256 private bobAmount = 50 ether;
    uint64 private deadline;

    function setUp() public {
        token = new MockERC20();
        deadline = uint64(block.timestamp + 7 days);

        bytes32 leafAlice = keccak256(abi.encodePacked(alice, aliceAmount));
        bytes32 leafBob = keccak256(abi.encodePacked(bob, bobAmount));
        root = leafAlice < leafBob
            ? keccak256(abi.encodePacked(leafAlice, leafBob))
            : keccak256(abi.encodePacked(leafBob, leafAlice));

        distributor = new MerkleDistributor(address(token), root, deadline, treasury, owner);
        token.mint(address(distributor), 1000 ether);
    }

    function _proofForAlice() private view returns (bytes32[] memory proof) {
        proof = new bytes32[](1);
        proof[0] = keccak256(abi.encodePacked(bob, bobAmount));
    }

    function testClaim_ValidProofTransfers() public {
        distributor.claim(alice, aliceAmount, _proofForAlice());
        assert(token.balanceOf(alice) == aliceAmount);
        assert(distributor.hasClaimed(alice));
    }

    function testClaim_DoubleClaimReverts() public {
        distributor.claim(alice, aliceAmount, _proofForAlice());
        vm.expectRevert(MerkleDistributor.AlreadyClaimed.selector);
        distributor.claim(alice, aliceAmount, _proofForAlice());
    }

    function testClaim_InvalidProofReverts() public {
        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = keccak256("nope");
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(alice, aliceAmount, badProof);
    }

    function testClaim_AfterDeadlineReverts() public {
        vm.warp(uint256(deadline) + 1);
        vm.expectRevert(MerkleDistributor.ClaimWindowClosed.selector);
        distributor.claim(alice, aliceAmount, _proofForAlice());
    }

    function testReclaim_BeforeDeadlineReverts() public {
        vm.expectRevert(MerkleDistributor.ClaimWindowOpen.selector);
        distributor.reclaim();
    }

    function testReclaim_AfterDeadlineSweepsToTreasury() public {
        distributor.claim(alice, aliceAmount, _proofForAlice());
        vm.warp(uint256(deadline) + 1);

        distributor.reclaim();
        assert(token.balanceOf(treasury) == 1000 ether - aliceAmount);

        vm.expectRevert(MerkleDistributor.AlreadyReclaimed.selector);
        distributor.reclaim();
    }

    function testReclaim_OnlyOwner() public {
        vm.warp(uint256(deadline) + 1);
        vm.prank(outsider);
        vm.expectRevert();
        distributor.reclaim();
    }

    function testSnapshotAnchor_OwnerWritesAndReads() public {
        HolderSnapshotAnchor anchor = new HolderSnapshotAnchor(owner);

        vm.expectRevert(HolderSnapshotAnchor.NoSnapshots.selector);
        anchor.latestSnapshot();

        uint256 id = anchor.anchorSnapshot(keccak256("root1"), 500 ether, "ipfs://snap1");
        assert(id == 0);
        assert(anchor.snapshotCount() == 1);
        assert(anchor.getSnapshot(0).totalSupply == 500 ether);
        assert(anchor.latestSnapshot().holderRoot == keccak256("root1"));
    }

    function testSnapshotAnchor_OnlyOwnerWrites() public {
        HolderSnapshotAnchor anchor = new HolderSnapshotAnchor(owner);
        vm.prank(outsider);
        vm.expectRevert();
        anchor.anchorSnapshot(keccak256("x"), 1, "uri");
    }
}
