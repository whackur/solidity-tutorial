// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title VulnerableVault — *external call before state update* (CEI violation)
/// @notice withdraw() sends ETH *before* zeroing the balance, so the receiver's `receive()` can re-enter and call withdraw() again.
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");

        // BAD: external call first → caller can re-enter
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "transfer failed");

        // The attacker re-enters multiple times before reaching this line
        balances[msg.sender] = 0;
    }

    receive() external payable {}
}
