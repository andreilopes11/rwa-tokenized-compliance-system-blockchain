// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Pluggable compliance rule bound to a single ModularCompliance instance.
/// @dev `moduleCheck` is a pure/view gate evaluated before a balance mutation.
///      The `*Action` hooks let stateful modules (e.g. holder counters) update
///      bookkeeping after a mutation and may only be called by the bound compliance.
interface IComplianceModule {
    /// @return True if the transfer/mint/burn is allowed by this module.
    function moduleCheck(address from, address to, uint256 amount, address compliance)
        external
        view
        returns (bool);

    function moduleTransferAction(address from, address to, uint256 amount) external;

    function moduleMintAction(address to, uint256 amount) external;

    function moduleBurnAction(address from, uint256 amount) external;

    /// @return Stable human-readable module name for audit artifacts.
    function name() external view returns (string memory);
}
