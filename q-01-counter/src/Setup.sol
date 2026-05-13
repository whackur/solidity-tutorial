// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Multi-tenant counter challenge. A single instance is deployed
///         once and shared by many users — each user has their own counter
///         keyed by msg.sender.
///
///         Goals (per caller):
///           1. Drive counts[msg.sender] to exactly 7.
///           2. Trigger a CounterUnderflow revert (decrement at zero),
///              read the 4-byte selector from the revert data, and submit
///              it back via reportUnderflowSelector.
///
///         Web UI grades by polling isSolved(msg.sender).
contract Counter {
    mapping(address => uint256) public counts;
    mapping(address => bool) public sawUnderflow;

    event Incremented(address indexed user, uint256 newCount);
    event Decremented(address indexed user, uint256 newCount);
    event Reset(address indexed user);
    event UnderflowSelectorReported(address indexed user, bytes4 selector);

    error CounterUnderflow();
    error WrongSelector(bytes4 submitted, bytes4 expected);

    function increment() external {
        unchecked {
            counts[msg.sender] += 1;
        }
        emit Incremented(msg.sender, counts[msg.sender]);
    }

    function decrement() external {
        if (counts[msg.sender] == 0) revert CounterUnderflow();
        unchecked {
            counts[msg.sender] -= 1;
        }
        emit Decremented(msg.sender, counts[msg.sender]);
    }

    function reset() external {
        counts[msg.sender] = 0;
        emit Reset(msg.sender);
    }

    /// @notice Submit the 4-byte selector you observed when decrement()
    ///         reverted at count == 0. Must match CounterUnderflow.selector.
    function reportUnderflowSelector(bytes4 selector) external {
        bytes4 expected = CounterUnderflow.selector;
        if (selector != expected) revert WrongSelector(selector, expected);
        sawUnderflow[msg.sender] = true;
        emit UnderflowSelectorReported(msg.sender, selector);
    }

    function isSolved(address user) external view returns (bool) {
        return counts[user] == 7 && sawUnderflow[user];
    }
}
