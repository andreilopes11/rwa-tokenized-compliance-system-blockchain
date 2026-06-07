// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseComplianceModule} from "./BaseComplianceModule.sol";

/// @notice Caps the post-transfer balance of any single holder.
contract MaxBalanceModule is BaseComplianceModule {
    IERC20 public token;
    uint256 public maxBalance;

    event TokenSet(address indexed token);
    event MaxBalanceSet(uint256 maxBalance);

    error TokenAlreadySet();
    error InvalidToken();

    constructor(address compliance_, address owner_, uint256 maxBalance_)
        BaseComplianceModule(compliance_, owner_)
    {
        maxBalance = maxBalance_;
    }

    function setToken(address tokenAddress) external onlyOwner {
        if (tokenAddress == address(0)) revert InvalidToken();
        if (address(token) != address(0)) revert TokenAlreadySet();
        token = IERC20(tokenAddress);
        emit TokenSet(tokenAddress);
    }

    function setMaxBalance(uint256 maxBalance_) external onlyOwner {
        maxBalance = maxBalance_;
        emit MaxBalanceSet(maxBalance_);
    }

    function moduleCheck(address, address to, uint256 amount, address querying)
        external
        view
        returns (bool)
    {
        if (!_boundCompliance(querying)) return false;
        if (maxBalance == 0 || to == address(0) || address(token) == address(0)) return true;
        // moduleCheck runs before the balance mutation, so add the incoming amount.
        return token.balanceOf(to) + amount <= maxBalance;
    }

    function name() external pure returns (string memory) {
        return "MaxBalanceModule";
    }
}
