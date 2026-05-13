// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @notice Local copy of the lecture's Counter — kept self-contained so the quiz
///         compiles without depending on the sibling `counter/` package layout.
/// @dev    Reference source: ../counter/src/Counter.sol
contract Counter {
    uint256 public count;

    event Incremented(address indexed by, uint256 newCount);
    event Decremented(address indexed by, uint256 newCount);
    event Reset(address indexed by);

    error CounterUnderflow();

    function increment() external {
        unchecked {
            count += 1;
        }
        emit Incremented(msg.sender, count);
    }

    function decrement() external {
        if (count == 0) revert CounterUnderflow();
        unchecked {
            count -= 1;
        }
        emit Decremented(msg.sender, count);
    }

    function reset() external {
        count = 0;
        emit Reset(msg.sender);
    }
}
