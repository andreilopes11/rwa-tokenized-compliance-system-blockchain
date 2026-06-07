// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Compliance surface consumed by the token at execution time.
interface IModularCompliance {
    function isWalletVerified(address wallet) external view returns (bool);

    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /// @dev Post-mutation bookkeeping hooks; callable only by the bound token.
    function transferred(address from, address to, uint256 amount) external;

    function created(address to, uint256 amount) external;

    function destroyed(address from, uint256 amount) external;
}
