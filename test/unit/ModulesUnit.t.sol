// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PauseModule} from "../../src/trex/modules/PauseModule.sol";
import {MaxBalanceModule} from "../../src/trex/modules/MaxBalanceModule.sol";
import {MaxHoldersModule} from "../../src/trex/modules/MaxHoldersModule.sol";
import {JurisdictionAllowModule} from "../../src/trex/modules/JurisdictionAllowModule.sol";
import {SuitabilityTierModule} from "../../src/trex/modules/SuitabilityTierModule.sol";
import {BaseComplianceModule} from "../../src/trex/modules/BaseComplianceModule.sol";
import {IdentityRegistryStorage} from "../../src/trex/registry/IdentityRegistryStorage.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {Vm} from "../../utils/foundry/Vm.sol";

/// @dev The test contract acts as the bound compliance (compliance == address(this)),
///      so module gates and action hooks can be exercised directly.
contract ModulesUnitTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private wrongCompliance = address(0xBEEF);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    MockERC20 private token;

    function setUp() public {
        token = new MockERC20();
    }

    function testPauseModule() public {
        PauseModule pm = new PauseModule(address(this), address(this));
        assert(pm.moduleCheck(address(0), alice, 1, address(this)));
        assert(!pm.moduleCheck(address(0), alice, 1, wrongCompliance)); // unbound querier
        pm.setPaused(true);
        assert(!pm.moduleCheck(address(0), alice, 1, address(this)));
        pm.moduleTransferAction(alice, bob, 1); // no-op, only-compliance
        assert(keccak256(bytes(pm.name())) == keccak256("PauseModule"));
    }

    function testBaseModule_ActionHookOnlyCompliance() public {
        PauseModule pm = new PauseModule(address(this), address(this));
        vm.prank(wrongCompliance);
        vm.expectRevert(BaseComplianceModule.NotCompliance.selector);
        pm.moduleMintAction(alice, 1);
    }

    function testMaxBalanceModule() public {
        MaxBalanceModule mb = new MaxBalanceModule(address(this), address(this), 0);
        assert(mb.moduleCheck(address(0), alice, 1, address(this))); // cap 0 = unlimited
        mb.setToken(address(token));
        vm.expectRevert(MaxBalanceModule.TokenAlreadySet.selector);
        mb.setToken(address(token));

        mb.setMaxBalance(100);
        token.mint(alice, 60);
        assert(mb.moduleCheck(address(0), alice, 40, address(this))); // 60+40 == 100 ok
        assert(!mb.moduleCheck(address(0), alice, 41, address(this))); // 60+41 > 100
        assert(!mb.moduleCheck(address(0), alice, 1, wrongCompliance));
        assert(mb.moduleCheck(address(0), address(0), 1, address(this))); // burn target
    }

    function testMaxHoldersModule() public {
        MaxHoldersModule mh = new MaxHoldersModule(address(this), address(this), 1);
        mh.setToken(address(token));
        vm.expectRevert(MaxHoldersModule.TokenAlreadySet.selector);
        mh.setToken(address(token));

        // Mint to alice -> she becomes the single allowed holder.
        token.mint(alice, 10);
        mh.moduleMintAction(alice, 10);
        assert(mh.holderCount() == 1);

        // A brand-new holder bob would exceed maxHolders(1).
        assert(!mh.moduleCheck(address(0), bob, 5, address(this)));

        // Raise the cap, then transfer makes bob a new holder.
        mh.setMaxHolders(5);
        token.mint(bob, 5);
        mh.moduleTransferAction(alice, bob, 5);
        assert(mh.holderCount() == 2);

        // Empty alice -> burn decrements holder count.
        token.burn(alice, 10);
        mh.moduleBurnAction(alice, 10);
        assert(mh.holderCount() == 1);
        assert(!mh.moduleCheck(address(0), bob, 1, wrongCompliance));
    }

    function testSuitabilityTierModule() public {
        SuitabilityTierModule su = new SuitabilityTierModule(address(this), address(this), 2);
        assert(su.moduleCheck(address(0), address(0), 1, address(this))); // burn target ok
        assert(!su.moduleCheck(address(0), alice, 1, address(this))); // tier 0 < 2
        su.setInvestorTier(alice, 2);
        assert(su.moduleCheck(address(0), alice, 1, address(this)));
        su.setRequiredTier(3);
        assert(!su.moduleCheck(address(0), alice, 1, address(this)));
        assert(!su.moduleCheck(address(0), alice, 1, wrongCompliance));
    }

    function testJurisdictionAllowModule() public {
        IdentityRegistryStorage idStorage = new IdentityRegistryStorage(address(this));
        idStorage.bindIdentityRegistry(address(this));
        idStorage.storeIdentity(alice, keccak256("a"), 840);

        JurisdictionAllowModule j =
            new JurisdictionAllowModule(address(this), address(this), address(idStorage));
        assert(j.moduleCheck(address(0), address(0), 1, address(this))); // burn target
        assert(!j.moduleCheck(address(0), alice, 1, address(this))); // 840 not allowed yet
        j.setJurisdiction(840, true);
        assert(j.moduleCheck(address(0), alice, 1, address(this)));
        assert(!j.moduleCheck(address(0), alice, 1, wrongCompliance));
    }

    function testModuleConstructor_RejectsZeroCompliance() public {
        vm.expectRevert(BaseComplianceModule.InvalidCompliance.selector);
        new PauseModule(address(0), address(this));
    }

    function testModuleNamesAndConstructorGuards() public {
        MaxBalanceModule mb = new MaxBalanceModule(address(this), address(this), 0);
        MaxHoldersModule mh = new MaxHoldersModule(address(this), address(this), 0);
        SuitabilityTierModule su = new SuitabilityTierModule(address(this), address(this), 0);

        IdentityRegistryStorage idStorage = new IdentityRegistryStorage(address(this));
        JurisdictionAllowModule j =
            new JurisdictionAllowModule(address(this), address(this), address(idStorage));

        assert(keccak256(bytes(mb.name())) == keccak256("MaxBalanceModule"));
        assert(keccak256(bytes(mh.name())) == keccak256("MaxHoldersModule"));
        assert(keccak256(bytes(su.name())) == keccak256("SuitabilityTierModule"));
        assert(keccak256(bytes(j.name())) == keccak256("JurisdictionAllowModule"));

        vm.expectRevert(MaxBalanceModule.InvalidToken.selector);
        mb.setToken(address(0));
        vm.expectRevert(MaxHoldersModule.InvalidToken.selector);
        mh.setToken(address(0));

        vm.expectRevert(JurisdictionAllowModule.InvalidStorage.selector);
        new JurisdictionAllowModule(address(this), address(this), address(0));
    }
}
