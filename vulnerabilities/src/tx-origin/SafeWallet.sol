// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title SafeWallet — authenticates the *direct caller* via `msg.sender`
contract SafeWallet {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function transfer(address payable to, uint256 amount) external {
        // GOOD: msg.sender is the *immediate* caller — intermediate contracts cannot bypass
        require(msg.sender == owner, "not owner");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
