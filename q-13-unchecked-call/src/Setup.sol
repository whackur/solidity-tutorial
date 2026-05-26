// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {SolvableBase} from "@common/SolvableBase.sol";

/// @notice Helper contract that always rejects ETH. Provided by the
///         challenge so learners don't need to deploy their own.
contract RevertOnReceive {
    error AlwaysReverts();

    receive() external payable {
        revert AlwaysReverts();
    }

    fallback() external payable {
        revert AlwaysReverts();
    }
}

/// @notice Escrow with a payout function that ignores the return value of
///         a low-level call. The state is advanced (escrow zeroed,
///         `paidOut` flag set) before the call AND regardless of whether
///         the call succeeded — so paying to a reverting receiver burns
///         the funds in the contract while still "marking" the user paid.
///
///         Multi-tenant: per-user keyed mappings, `address(this).balance`
///         tracked but not used for grading. The `stranded` field is
///         instructor-grade bookkeeping — a real bug would have no such
///         accounting at all.
contract UnsafePayout is SolvableBase {
    RevertOnReceive public immutable trap;

    mapping(address => uint256) public escrow;
    mapping(address => bool) public paidOut;
    mapping(address => uint256) public stranded;

    event Deposited(address indexed user, uint256 amount);
    event PayoutAttempted(address indexed user, address to, uint256 amount, bool ok);

    constructor() {
        trap = new RevertOnReceive();
    }

    function deposit() external payable {
        require(msg.value > 0, "no value");
        escrow[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Pay out the caller's escrow to `to`. BUG: the bool return
    ///         from the low-level call is captured but not asserted.
    function payout(address payable to) external {
        uint256 amount = escrow[msg.sender];
        require(amount > 0, "no escrow");

        // Effects first (these are correct in CEI order — the bug is
        // not reentrancy, it's silent failure-tolerance).
        escrow[msg.sender] = 0;
        paidOut[msg.sender] = true;

        // BUG: `ok` captured but ignored. Tutorial bookkeeping below
        // surfaces the silent failure for grading.
        (bool ok,) = to.call{value: amount}("");
        if (!ok) {
            stranded[msg.sender] += amount;
        }
        emit PayoutAttempted(msg.sender, to, amount, ok);
    }

    function isSolved(address user) public view override returns (bool) {
        // The user observably "paid out" yet the funds stayed in the contract
        // (proved by stranded > 0). That's the exact failure mode that
        // unchecked low-level calls hide in production.
        return paidOut[user] && stranded[user] > 0;
    }

    receive() external payable {}
}
