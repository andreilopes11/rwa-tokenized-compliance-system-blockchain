// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {TrexDeploy} from "../helpers/TrexDeploy.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

contract AgentOnlyFuzzTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TrexIdentityRegistry private registry;
    TrexModularCompliance private compliance;
    TrexToken private token;

    address private governanceAgent = address(0x600D);
    address private complianceAgent = address(0xC011);
    address private lifecycleAgent = address(0x1FEC0);
    address private transferManager = address(0x7AA7);

    function setUp() public {
        registry = new TrexIdentityRegistry(address(this), complianceAgent);
        compliance = TrexDeploy.deployCompliance(address(this), governanceAgent, address(registry));
        token = new TrexToken(
            "VaultGuard Tokenized RWA",
            "VGRWA",
            address(this),
            governanceAgent,
            lifecycleAgent,
            transferManager,
            address(compliance),
            0
        );
        compliance.bindToken(address(token));
    }

    function _isPrivileged(address caller) private view returns (bool) {
        return caller == address(0) || caller == address(this) || caller == governanceAgent
            || caller == complianceAgent || caller == lifecycleAgent || caller == transferManager;
    }

    function testFuzz_NonAgentCannotMint(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        token.mint(caller, 1 ether);
    }

    function testFuzz_NonAgentCannotPause(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        token.pause();
    }

    function testFuzz_NonAgentCannotRegisterIdentity(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        registry.registerIdentity(caller, keccak256("x"));
    }

    function testFuzz_NonAgentCannotManageModulesOrLimits(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        compliance.addModule(caller);

        vm.prank(caller);
        vm.expectRevert();
        compliance.setLimits(1);
    }

    function testFuzz_NonAgentCannotForceTransfer(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        token.forceTransfer(caller, address(this), 1);
    }

    function testFuzz_NonUpgraderCannotUpgrade(address caller) public {
        if (_isPrivileged(caller)) return;
        vm.prank(caller);
        vm.expectRevert();
        compliance.upgradeToAndCall(address(token), "");
    }
}
