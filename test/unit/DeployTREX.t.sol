// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DeployTREX} from "../../script/deploy/DeployTREX.s.sol";

contract DeployTREXHarness is DeployTREX {
    function hasOverlappingAssignments(
        address superAdmin,
        address governanceAgent,
        address complianceAgent,
        address lifecycleAgent,
        address transferManagerAgent
    ) external pure returns (bool) {
        return _hasOverlappingSoDAssignments(
            superAdmin,
            governanceAgent,
            complianceAgent,
            lifecycleAgent,
            transferManagerAgent
        );
    }
}

contract DeployTREXTest {
    DeployTREXHarness private harness;

    function setUp() public {
        harness = new DeployTREXHarness();
    }

    function testDistinctPrivilegedAgentsPassSoDValidation() public view {
        bool overlaps = harness.hasOverlappingAssignments(
            address(0xA11CE),
            address(0x600D),
            address(0xC011),
            address(0x1FEC0),
            address(0x7AA7)
        );
        assert(!overlaps);
    }

    function testOverlappingGovernanceAndComplianceFailsSoDValidation() public view {
        bool overlaps = harness.hasOverlappingAssignments(
            address(0xA11CE),
            address(0x600D),
            address(0x600D),
            address(0x1FEC0),
            address(0x7AA7)
        );
        assert(overlaps);
    }

    function testLifecycleOrTransferManagerSharingPrivilegedKeyFailsSoDValidation() public view {
        bool lifecycleOverlaps = harness.hasOverlappingAssignments(
            address(0xA11CE),
            address(0x600D),
            address(0xC011),
            address(0xA11CE),
            address(0x7AA7)
        );
        assert(lifecycleOverlaps);

        bool transferManagerOverlaps = harness.hasOverlappingAssignments(
            address(0xA11CE),
            address(0x600D),
            address(0xC011),
            address(0x1FEC0),
            address(0xA11CE)
        );
        assert(transferManagerOverlaps);
    }
}
