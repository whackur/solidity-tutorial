// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ISolvable} from "./ISolvable.sol";

/// @notice Drop-in base for every challenge contract. Implements solve() and
///         tracks who has solved. Subclasses only need to override isSolved.
///
///         The contract intentionally separates two states:
///           - isSolved(user): live view of the puzzle condition. Free to flip
///             back to false after the user resets challenge state.
///           - solvedBy[user]: sticky proof-of-solve. Set on a successful
///             solve() call and never cleared, so off-chain tooling has a
///             permanent record without re-running the puzzle.
abstract contract SolvableBase is ISolvable {
    mapping(address => bool) public override solvedBy;

    function isSolved(address user) public view virtual override returns (bool);

    function solve() external override {
        if (solvedBy[msg.sender]) revert AlreadySolved();
        if (!isSolved(msg.sender)) revert NotSolved();
        solvedBy[msg.sender] = true;
        emit Solved(msg.sender);
    }
}
