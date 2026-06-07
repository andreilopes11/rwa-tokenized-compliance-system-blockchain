// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC-3643 trusted claim issuers and the topics each issuer may attest.
contract TrustedIssuersRegistry is Ownable {
    mapping(address issuer => uint256[] topics) private issuerTopics;
    mapping(address issuer => bool trusted) private trusted;
    address[] private issuers;

    event TrustedIssuerAdded(address indexed issuer, uint256[] topics);
    event TrustedIssuerRemoved(address indexed issuer);

    error InvalidIssuer();
    error IssuerAlreadyTrusted(address issuer);
    error IssuerNotTrusted(address issuer);
    error EmptyTopics();

    constructor(address owner_) Ownable(owner_) {}

    function addTrustedIssuer(address issuer, uint256[] calldata topics) external onlyOwner {
        if (issuer == address(0)) revert InvalidIssuer();
        if (trusted[issuer]) revert IssuerAlreadyTrusted(issuer);
        if (topics.length == 0) revert EmptyTopics();
        trusted[issuer] = true;
        issuerTopics[issuer] = topics;
        issuers.push(issuer);
        emit TrustedIssuerAdded(issuer, topics);
    }

    function removeTrustedIssuer(address issuer) external onlyOwner {
        if (!trusted[issuer]) revert IssuerNotTrusted(issuer);
        trusted[issuer] = false;
        delete issuerTopics[issuer];
        uint256 length = issuers.length;
        for (uint256 i = 0; i < length; i++) {
            if (issuers[i] == issuer) {
                issuers[i] = issuers[length - 1];
                issuers.pop();
                break;
            }
        }
        emit TrustedIssuerRemoved(issuer);
    }

    function isTrustedIssuer(address issuer) external view returns (bool) {
        return trusted[issuer];
    }

    function hasClaimTopic(address issuer, uint256 topic) external view returns (bool) {
        if (!trusted[issuer]) return false;
        uint256[] storage topics = issuerTopics[issuer];
        for (uint256 i = 0; i < topics.length; i++) {
            if (topics[i] == topic) return true;
        }
        return false;
    }

    function getTrustedIssuers() external view returns (address[] memory) {
        return issuers;
    }
}
