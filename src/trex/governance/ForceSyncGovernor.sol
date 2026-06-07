// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal target surface: the identity registry's jurisdiction-aware registration.
interface IForceSyncTarget {
    function registerIdentity(address wallet, bytes32 referenceHash, uint16 country) external;
}

/// @notice Dedicated N-owner / 2-of-N governor for the on-chain "force sync" emergency
///         path. Two distinct owners must submit identical parameters before the identity
///         is (re)synced on-chain. Mirrors the backend four-eyes ForceSync control.
contract ForceSyncGovernor {
    IForceSyncTarget public immutable target;
    uint256 public immutable threshold;
    address[] private owners;
    mapping(address account => bool isOwner) public isOwner;

    struct Operation {
        bool exists;
        bool executed;
        bytes32 referenceHash;
        uint16 country;
        uint256 approvals;
    }

    mapping(bytes32 opId => Operation operation) public operations;
    mapping(bytes32 opId => mapping(address owner => bool approved)) public approvedBy;

    event ForceSyncProposed(bytes32 indexed opId, address indexed wallet, address indexed owner);
    event ForceSyncApproved(bytes32 indexed opId, address indexed owner, uint256 approvals);
    event ForceSyncExecuted(bytes32 indexed opId, address indexed wallet);

    error NotOwner();
    error DuplicateApproval();
    error AlreadyExecuted();
    error InvalidOwners();
    error InvalidThreshold();
    error InvalidTarget();

    constructor(address[] memory owners_, uint256 threshold_, address target_) {
        if (target_ == address(0)) revert InvalidTarget();
        if (owners_.length < 2) revert InvalidOwners();
        if (threshold_ < 2 || threshold_ > owners_.length) revert InvalidThreshold();
        for (uint256 i = 0; i < owners_.length; i++) {
            address owner = owners_[i];
            if (owner == address(0) || isOwner[owner]) revert InvalidOwners();
            isOwner[owner] = true;
            owners.push(owner);
        }
        threshold = threshold_;
        target = IForceSyncTarget(target_);
    }

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    /// @notice Submit (and implicitly approve) a force-sync. Executes once `threshold`
    ///         distinct owners have submitted identical parameters.
    function forceSyncOnChain(address wallet, bytes32 referenceHash, uint16 country)
        external
        onlyOwner
        returns (bytes32 opId)
    {
        opId = keccak256(abi.encode(wallet, referenceHash, country));
        Operation storage op = operations[opId];
        if (op.executed) revert AlreadyExecuted();
        if (approvedBy[opId][msg.sender]) revert DuplicateApproval();

        if (!op.exists) {
            op.exists = true;
            op.referenceHash = referenceHash;
            op.country = country;
            emit ForceSyncProposed(opId, wallet, msg.sender);
        }

        approvedBy[opId][msg.sender] = true;
        op.approvals += 1;
        emit ForceSyncApproved(opId, msg.sender, op.approvals);

        if (op.approvals >= threshold) {
            op.executed = true;
            target.registerIdentity(wallet, referenceHash, country);
            emit ForceSyncExecuted(opId, wallet);
        }
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
