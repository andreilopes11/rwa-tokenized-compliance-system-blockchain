// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC-3643 claim topics required for an investor identity to be eligible.
/// @dev Owner is expected to be the governance Safe / TimelockController in production.
contract ClaimTopicsRegistry is Ownable {
    uint256[] private claimTopics;
    mapping(uint256 topic => bool present) private known;

    event ClaimTopicAdded(uint256 indexed topic);
    event ClaimTopicRemoved(uint256 indexed topic);

    error TopicAlreadyExists(uint256 topic);
    error TopicNotFound(uint256 topic);

    constructor(address owner_) Ownable(owner_) {}

    function addClaimTopic(uint256 topic) external onlyOwner {
        if (known[topic]) revert TopicAlreadyExists(topic);
        known[topic] = true;
        claimTopics.push(topic);
        emit ClaimTopicAdded(topic);
    }

    function removeClaimTopic(uint256 topic) external onlyOwner {
        if (!known[topic]) revert TopicNotFound(topic);
        known[topic] = false;
        uint256 length = claimTopics.length;
        for (uint256 i = 0; i < length; i++) {
            if (claimTopics[i] == topic) {
                claimTopics[i] = claimTopics[length - 1];
                claimTopics.pop();
                break;
            }
        }
        emit ClaimTopicRemoved(topic);
    }

    function getClaimTopics() external view returns (uint256[] memory) {
        return claimTopics;
    }

    function requiredTopicCount() external view returns (uint256) {
        return claimTopics.length;
    }
}
