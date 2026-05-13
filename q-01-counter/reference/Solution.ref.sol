// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
// To verify the challenge end-to-end, copy this file's contract body into
// ../src/Solution.sol temporarily, run `forge test`, then restore the stub.

import {Counter} from "../src/Setup.sol";

contract SolutionRef {
    function solve(Counter c) external {
        for (uint256 i = 0; i < 7; ++i) {
            c.increment();
        }
    }

    function catchUnderflow(Counter c) external returns (bytes4 sel) {
        try c.decrement() {
            revert("expected revert");
        } catch (bytes memory reason) {
            assembly {
                sel := mload(add(reason, 0x20))
            }
        }
    }
}
