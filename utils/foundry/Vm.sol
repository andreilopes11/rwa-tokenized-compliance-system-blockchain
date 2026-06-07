// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Vm {
    function addr(uint256 privateKey) external returns (address);

    function envUint(string calldata name) external returns (uint256);

    function envAddress(string calldata name) external returns (address);

    function envString(string calldata name) external returns (string memory);

    function envOr(string calldata name, uint256 defaultValue) external returns (uint256);

    function envOr(string calldata name, address defaultValue) external returns (address);

    function warp(uint256 newTimestamp) external;

    function expectEmit(
        bool checkTopic1,
        bool checkTopic2,
        bool checkTopic3,
        bool checkData
    ) external;

    function expectRevert() external;

    function expectRevert(bytes4 selector) external;

    function expectRevert(bytes calldata revertData) external;

    function prank(address sender) external;

    function serializeAddress(
        string calldata objectKey,
        string calldata valueKey,
        address value
    ) external returns (string memory);

    function serializeString(
        string calldata objectKey,
        string calldata valueKey,
        string calldata value
    ) external returns (string memory);

    function serializeUint(string calldata objectKey, string calldata valueKey, uint256 value)
        external
        returns (string memory);

    function serializeBool(string calldata objectKey, string calldata valueKey, bool value)
        external
        returns (string memory);

    function startBroadcast(uint256 privateKey) external;

    function stopBroadcast() external;

    function writeJson(string calldata json, string calldata path) external;
}
