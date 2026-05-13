// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @dev Local copy of ../vulnerabilities/src/reentrancy/VulnerableVault.sol
contract VulnerableVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "no balance");

        // BAD: external call before state update
        (bool ok,) = msg.sender.call{value: bal}("");
        require(ok, "transfer failed");

        balances[msg.sender] = 0;
    }

    receive() external payable {}
}

interface IVulnerableVault {
    function deposit() external payable;
    function withdraw() external;
}
