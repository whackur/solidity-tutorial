// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SafeVault — Checks-Effects-Interactions (CEI) + ReentrancyGuard double defense
contract SafeVault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");

        // GOOD: zero the balance *before* the external call
        balances[msg.sender] = 0;

        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "transfer failed");
    }

    receive() external payable {}
}
