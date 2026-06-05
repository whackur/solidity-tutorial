// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/// @title Counter — minimal contract for the Solidity entry-level lecture
/// @notice The simplest combination of state variable + function visibility + event + custom error.
///         Exposes the same operations over two kinds of state so students can
///         compare them on one shared deployment:
///         - `count`: a single SHARED slot — every caller mutates the same value
///           (and anyone's `reset` wipes it for everyone).
///         - `counts[msg.sender]`: a PERSONAL slot per caller — students never
///           interfere with each other (same keying as the q-01 challenge).
contract Counter {
    uint256 public count;
    mapping(address => uint256) public counts;

    event Incremented(address indexed by, uint256 newCount);
    event Decremented(address indexed by, uint256 newCount);
    event Reset(address indexed by);
    event PersonalIncremented(address indexed by, uint256 newCount);
    event PersonalDecremented(address indexed by, uint256 newCount);
    event PersonalReset(address indexed by);

    error CounterUnderflow();

    /*//////////////////////////////////////////////////////////////
                      SHARED COUNTER (one slot for all)
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                    PERSONAL COUNTER (one slot per caller)
    //////////////////////////////////////////////////////////////*/

    function incrementPersonal() external {
        unchecked {
            counts[msg.sender] += 1;
        }
        emit PersonalIncremented(msg.sender, counts[msg.sender]);
    }

    function decrementPersonal() external {
        if (counts[msg.sender] == 0) revert CounterUnderflow();
        unchecked {
            counts[msg.sender] -= 1;
        }
        emit PersonalDecremented(msg.sender, counts[msg.sender]);
    }

    function resetPersonal() external {
        counts[msg.sender] = 0;
        emit PersonalReset(msg.sender);
    }
}
