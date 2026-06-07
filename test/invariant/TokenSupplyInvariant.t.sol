// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TrexIdentityRegistry} from "../../src/trex/TrexIdentityRegistry.sol";
import {TrexModularCompliance} from "../../src/trex/TrexModularCompliance.sol";
import {TrexToken} from "../../src/trex/TrexToken.sol";
import {TrexDeploy} from "../helpers/TrexDeploy.sol";

/// @notice Drives valid mint/transfer/burn flows so invariants are exercised against real
///         state mutations. All token ops originate from this handler (the lifecycle agent
///         and a registered holder), so balances are confined to {handler} + actors.
contract SupplyHandler {
    TrexToken private immutable token;
    uint256 private immutable maxSupply;
    address[] public actors;

    constructor(TrexToken token_, uint256 maxSupply_, address[] memory actors_) {
        token = token_;
        maxSupply = maxSupply_;
        actors = actors_;
    }

    function mint(uint256 amount) external {
        uint256 remaining = maxSupply - token.totalSupply();
        if (remaining == 0) return;
        amount = (amount % remaining) + 1;
        token.mint(address(this), amount);
    }

    function moveToActor(uint256 actorSeed, uint256 amount) external {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;
        amount = (amount % balance) + 1;
        token.transfer(actors[actorSeed % actors.length], amount);
    }

    function burn(uint256 amount) external {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;
        amount = (amount % balance) + 1;
        token.burn(amount);
    }
}

contract TokenSupplyInvariantTest {
    uint256 private constant MAX_SUPPLY = 1_000_000 ether;

    TrexIdentityRegistry private registry;
    TrexModularCompliance private compliance;
    TrexToken private token;
    SupplyHandler private handler;
    address[] private holders;

    function setUp() public {
        address governanceAgent = address(0x600D);
        address transferManager = address(0x7AA7);

        registry = new TrexIdentityRegistry(address(this), address(this));
        compliance = TrexDeploy.deployCompliance(address(this), governanceAgent, address(registry));
        token = new TrexToken(
            "VaultGuard Tokenized RWA",
            "VGRWA",
            address(this),
            governanceAgent,
            address(this), // temporary lifecycle agent; re-granted to the handler below
            transferManager,
            address(compliance),
            MAX_SUPPLY
        );
        compliance.bindToken(address(token));

        address[] memory actors = new address[](3);
        actors[0] = address(0xA11CE);
        actors[1] = address(0xB0B);
        actors[2] = address(0xCA0A);

        handler = new SupplyHandler(token, MAX_SUPPLY, actors);

        // Register all holders (handler + actors) and grant the handler mint rights.
        registry.registerIdentity(address(handler), keccak256("handler"), 1);
        for (uint256 i = 0; i < actors.length; i++) {
            registry.registerIdentity(actors[i], keccak256(abi.encodePacked(i)), 1);
            holders.push(actors[i]);
        }
        holders.push(address(handler));

        token.grantRole(token.LIFECYCLE_ROLE(), address(handler));
    }

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function invariant_supplyWithinCap() public view {
        assert(token.totalSupply() <= MAX_SUPPLY);
    }

    function invariant_balancesSumToSupply() public view {
        uint256 sum;
        for (uint256 i = 0; i < holders.length; i++) {
            sum += token.balanceOf(holders[i]);
        }
        assert(sum == token.totalSupply());
    }
}
