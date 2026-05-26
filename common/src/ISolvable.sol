// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Shared interface every challenge implements so the grader and the
///         web UI can interact with all of them through one ABI.
///
///         isSolved(user)   — view-only state check. May flip back to false
///                            if the challenge state is reset.
///         solve()          — caller proves the solve on-chain. Reverts when
///                            isSolved(msg.sender) is false (NotSolved) or
///                            when the caller has already solved at least
///                            once (AlreadySolved). Emits Solved on success.
///         solvedBy(user)   — sticky flag that records each address that has
///                            ever successfully called solve().
interface ISolvable {
    event Solved(address indexed user);

    error NotSolved();
    error AlreadySolved();

    function isSolved(address user) external view returns (bool);
    function solve() external;
    function solvedBy(address user) external view returns (bool);
}
