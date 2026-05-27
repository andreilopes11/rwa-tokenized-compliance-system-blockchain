// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ITrexIdentityRegistry {
    function isVerified(address wallet) external view returns (bool);
}
