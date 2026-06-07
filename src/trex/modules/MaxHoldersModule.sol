// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseComplianceModule} from "./BaseComplianceModule.sol";

/// @notice Caps the number of distinct token holders. Holder count is maintained from
///         the post-mutation action hooks fired by the bound token via the compliance.
contract MaxHoldersModule is BaseComplianceModule {
    IERC20 public token;
    uint256 public maxHolders;
    uint256 public holderCount;

    event TokenSet(address indexed token);
    event MaxHoldersSet(uint256 maxHolders);

    error TokenAlreadySet();
    error InvalidToken();

    constructor(address compliance_, address owner_, uint256 maxHolders_)
        BaseComplianceModule(compliance_, owner_)
    {
        maxHolders = maxHolders_;
    }

    function setToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidToken();
        if (address(token) != address(0)) revert TokenAlreadySet();
        token = IERC20(tokenAddress);
        emit TokenSet(tokenAddress);
    }

    function setMaxHolders(uint256 maxHolders_) external onlyOwner {
        maxHolders = maxHolders_;
        emit MaxHoldersSet(maxHolders_);
    }

    function moduleCheck(address, address to, uint256 amount, address querying)
        external
        view
        returns (bool)
    {
        if (!_boundCompliance(querying)) return false;
        if (maxHolders == 0 || to == address(0) || address(token) == address(0)) return true;
        bool newHolder = amount > 0 && token.balanceOf(to) == 0;
        if (!newHolder) return true;
        return holderCount + 1 <= maxHolders;
    }

    function moduleMintAction(address to, uint256 amount) external override onlyCompliance {
        if (amount > 0 && token.balanceOf(to) == amount) holderCount += 1;
    }

    function moduleBurnAction(address from, uint256) external override onlyCompliance {
        if (token.balanceOf(from) == 0 && holderCount > 0) holderCount -= 1;
    }

    function moduleTransferAction(address from, address to, uint256 amount)
        external
        override
        onlyCompliance
    {
        if (from == to) return;
        if (amount > 0 && token.balanceOf(to) == amount) holderCount += 1;
        if (token.balanceOf(from) == 0 && holderCount > 0) holderCount -= 1;
    }

    function name() external pure returns (string memory) {
        return "MaxHoldersModule";
    }
}
