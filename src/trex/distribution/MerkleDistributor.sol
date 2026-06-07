// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Merkle-based distribution with a bounded claim window. After the window,
///         unclaimed funds are reclaimable to the tenant treasury (never burned/stuck).
contract MerkleDistributor is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;
    uint64 public immutable claimDeadline;
    address public immutable tenantTreasury;

    mapping(address account => bool claimed) public hasClaimed;
    bool public reclaimed;

    event Claimed(address indexed account, uint256 amount);
    event Reclaimed(address indexed treasury, uint256 amount);

    error ClaimWindowClosed();
    error ClaimWindowOpen();
    error AlreadyClaimed();
    error InvalidProof();
    error AlreadyReclaimed();
    error InvalidTreasury();

    constructor(
        address token_,
        bytes32 merkleRoot_,
        uint64 claimDeadline_,
        address tenantTreasury_,
        address owner_
    ) Ownable(owner_) {
        if (tenantTreasury_ == address(0)) revert InvalidTreasury();
        token = IERC20(token_);
        merkleRoot = merkleRoot_;
        claimDeadline = claimDeadline_;
        tenantTreasury = tenantTreasury_;
    }

    /// @param amount Entitlement encoded in the Merkle leaf `keccak256(account, amount)`.
    function claim(address account, uint256 amount, bytes32[] calldata proof) external {
        if (block.timestamp > claimDeadline) revert ClaimWindowClosed();
        if (hasClaimed[account]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        hasClaimed[account] = true;
        token.safeTransfer(account, amount);
        emit Claimed(account, amount);
    }

    /// @notice Sweep unclaimed tokens to the tenant treasury after the window closes.
    function reclaim() external onlyOwner {
        if (block.timestamp <= claimDeadline) revert ClaimWindowOpen();
        if (reclaimed) revert AlreadyReclaimed();
        reclaimed = true;
        uint256 remaining = token.balanceOf(address(this));
        token.safeTransfer(tenantTreasury, remaining);
        emit Reclaimed(tenantTreasury, remaining);
    }
}
