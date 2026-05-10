// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";

contract PermissionedToken is ERC20, ERC20Burnable, Ownable, Pausable {
    IIdentityRegistry public immutable identityRegistry;

    error InvalidRegistry();
    error WalletNotVerified(address wallet);

    constructor(
        string memory name_,
        string memory symbol_,
        address registry_,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        if (registry_ == address(0)) revert InvalidRegistry();
        identityRegistry = IIdentityRegistry(registry_);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        if (from != address(0) && !identityRegistry.isVerified(from)) revert WalletNotVerified(from);
        if (to != address(0) && !identityRegistry.isVerified(to)) revert WalletNotVerified(to);

        super._update(from, to, value);
    }
}
