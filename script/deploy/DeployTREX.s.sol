// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Testnet Public T-REX deploy (PLANNED).
/// @dev Install dependency: `forge install TokenySolutions/T-REX --no-commit` then implement suite deploy.
///      Until then this script reverts with a clear message.
contract DeployTREX {
    error TrexNotInstalled();

    function run() external pure {
        revert TrexNotInstalled();
    }
}
