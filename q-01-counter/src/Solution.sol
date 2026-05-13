// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Counter} from "./Setup.sol";

/// @notice Fill in the TODO bodies. Do NOT modify Setup.sol.
/// @dev    Run `forge test -vv` to check your work.
contract Solution {
    /// @notice Make `c.count() == 7` after this function returns.
    function solve(Counter c) external {
        // TODO: drive `c` so that its count is exactly 7.
        //       Hint 1: c.increment() bumps count by 1 — what's the simplest loop?
        //       Hint 2: c.reset() resets to 0, c.decrement() reverts on underflow.
        c; // silence unused-variable warning until you implement this
        revert("Solution.solve: not implemented");
    }

    /// @notice Call `c.decrement()` while count == 0 and return the 4-byte
    ///         selector of the revert.
    function catchUnderflow(Counter c) external returns (bytes4 sel) {
        // TODO: invoke c.decrement(), catch the revert, extract the selector.
        //       Hint 1: `try ... catch (bytes memory reason) { ... }`
        //       Hint 2: the first 32 bytes of `reason` start with the 4-byte selector.
        c;
        sel;
        revert("Solution.catchUnderflow: not implemented");
    }
}
