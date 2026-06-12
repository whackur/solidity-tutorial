// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TokenBank — demonstrates the ERC-20 pull (approve + transferFrom) pattern.
///
/// The bank is the SPENDER. A depositor must call `token.approve(bank, amount)` before
/// calling `deposit`. Without an allowance the `transferFrom` inside `deposit` will revert.
///
/// Withdrawal uses a plain `transfer` — no allowance required because the bank already
/// owns the tokens it is sending back.
contract TokenBank {
    /// @notice The ERC-20 token this bank accepts.
    IERC20 public immutable token;

    /// @notice Token balance held by the bank on behalf of each depositor.
    mapping(address => uint256) public balances;

    constructor(IERC20 token_) {
        token = token_;
    }

    /// @notice Pull `amount` tokens from the caller into the bank.
    /// @dev Caller must have approved this contract for at least `amount` tokens.
    ///      This is the transferFrom (spender) side of the approve + transferFrom flow.
    function deposit(uint256 amount) external {
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Return `amount` tokens to the caller from the bank.
    /// @dev Uses a plain `transfer` — the bank owns these tokens, so no allowance is needed.
    function withdraw(uint256 amount) external {
        balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }
}
