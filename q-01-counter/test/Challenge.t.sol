// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q01Counter} from "../src/Setup.sol";

contract Q01CounterPublicTest is Test {
    Q01Counter internal counter;
    address internal alice = makeAddr("alice");

    function setUp() public {
        counter = new Q01Counter();
    }

    function test_InitialStateIsUnsolved() public view {
        assertEq(counter.counts(alice), 0);
        assertFalse(counter.sawUnderflow(alice));
        assertFalse(counter.isSolved(alice));
    }

    function test_BasicCounterStateIsPerUser() public {
        vm.prank(alice);
        counter.increment();

        assertEq(counter.counts(alice), 1);
        assertEq(counter.counts(address(this)), 0);
        assertFalse(counter.isSolved(alice));
    }
}
