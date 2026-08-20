// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

interface IAddressAllowlist {
    function isAllowed(address account) external view returns (bool);
}
