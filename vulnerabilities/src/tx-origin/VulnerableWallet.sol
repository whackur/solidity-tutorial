// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title VulnerableWallet — owner is authenticated via `tx.origin`
/// @notice Any contract the owner happens to call can drain this wallet
contract VulnerableWallet {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function transfer(address payable to, uint256 amount) external {
        // BAD: tx.origin is the *outermost EOA* — an intermediate contract can sneak in
        require(tx.origin == owner, "not owner");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "send failed");
    }

    receive() external payable {}
}
