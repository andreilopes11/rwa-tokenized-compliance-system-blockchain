// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexModularComplianceV2} from "../mocks/TrexModularComplianceV2.sol";
import {TrexDeploy} from "../helpers/TrexDeploy.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract TimelockUpgradeTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 private constant MIN_DELAY = 86_400; // 24h

    TrexIdentityRegistry private registry;
    TrexModularCompliance private compliance;
    TimelockController private timelock;
    address private newImpl;

    address private superAdmin = address(this);
    address private governanceAgent = address(0x600D);
    address private complianceAgent = address(0xC011);
    address private outsider = address(0xDEAD);

    function setUp() public {
        registry = new TrexIdentityRegistry(superAdmin, complianceAgent);
        compliance = TrexDeploy.deployCompliance(superAdmin, governanceAgent, address(registry));

        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        timelock = new TimelockController(MIN_DELAY, proposers, executors, address(0));

        // Only the timelock may upgrade.
        compliance.grantRole(compliance.UPGRADER_ROLE(), address(timelock));

        newImpl = address(new TrexModularComplianceV2());
    }

    function testUpgrade_DirectUpgradeWithoutTimelockReverts() public {
        // Caller holds DEFAULT_ADMIN + GOVERNANCE but not UPGRADER_ROLE.
        vm.expectRevert();
        compliance.upgradeToAndCall(newImpl, "");

        vm.prank(outsider);
        vm.expectRevert();
        compliance.upgradeToAndCall(newImpl, "");
    }

    function testUpgrade_TimelockScheduledUpgradeSucceeds() public {
        bytes memory data =
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImpl, bytes(""));

        timelock.schedule(address(compliance), 0, data, bytes32(0), bytes32(0), MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        timelock.execute(address(compliance), 0, data, bytes32(0), bytes32(0));

        assert(TrexModularComplianceV2(address(compliance)).version() == 2);
    }

    function testUpgrade_ExecuteBeforeDelayReverts() public {
        bytes memory data =
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImpl, bytes(""));
        timelock.schedule(address(compliance), 0, data, bytes32(0), bytes32(0), MIN_DELAY);

        vm.expectRevert();
        timelock.execute(address(compliance), 0, data, bytes32(0), bytes32(0));
    }
}
