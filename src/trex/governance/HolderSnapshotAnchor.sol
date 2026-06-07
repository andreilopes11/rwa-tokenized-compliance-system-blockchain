// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Append-only anchor for off-chain holder snapshots. Only the governance owner
///         (Safe / TimelockController) may write. Stores a Merkle root + supply + URI per
///         snapshot for distributions and audit reconciliation. No PII on-chain.
contract HolderSnapshotAnchor is Ownable {
    struct Snapshot {
        bytes32 holderRoot;
        uint256 totalSupply;
        uint64 timestamp;
        string uri;
    }

    Snapshot[] private snapshots;

    event SnapshotAnchored(
        uint256 indexed snapshotId, bytes32 indexed holderRoot, uint256 totalSupply, string uri
    );

    error NoSnapshots();

    constructor(address owner_) Ownable(owner_) {}

    function anchorSnapshot(bytes32 holderRoot, uint256 totalSupply, string calldata uri)
        external
        onlyOwner
        returns (uint256 snapshotId)
    {
        snapshotId = snapshots.length;
        snapshots.push(
            Snapshot({
                holderRoot: holderRoot,
                totalSupply: totalSupply,
                timestamp: uint64(block.timestamp),
                uri: uri
            })
        );
        emit SnapshotAnchored(snapshotId, holderRoot, totalSupply, uri);
    }

    function snapshotCount() external view returns (uint256) {
        return snapshots.length;
    }

    function getSnapshot(uint256 snapshotId) external view returns (Snapshot memory) {
        return snapshots[snapshotId];
    }

    function latestSnapshot() external view returns (Snapshot memory) {
        if (snapshots.length == 0) revert NoSnapshots();
        return snapshots[snapshots.length - 1];
    }
}
