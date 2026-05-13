// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q01CounterTest is Test {
    Counter internal counter;
    Solution internal sol;

    function setUp() public {
        counter = new Counter();
        sol = new Solution();
    }

    function test_Solve() public {
        sol.solve(counter);
        assertEq(counter.count(), 7, "count must equal 7");
    }

    function test_CatchUnderflow() public {
        bytes4 sel = sol.catchUnderflow(counter);
        assertEq(sel, Counter.CounterUnderflow.selector, "must return CounterUnderflow selector");
    }
}
