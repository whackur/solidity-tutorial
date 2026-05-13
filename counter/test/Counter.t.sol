// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter internal counter;
    address internal user = address(0xBEEF);

    event Incremented(address indexed by, uint256 newCount);
    event Reset(address indexed by);

    function setUp() public {
        counter = new Counter();
    }

    function test_InitialCountIsZero() public view {
        assertEq(counter.count(), 0);
    }

    function test_IncrementEmitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit Incremented(user, 1);
        counter.increment();
        assertEq(counter.count(), 1);
    }

    function test_DecrementRevertsOnUnderflow() public {
        vm.expectRevert(Counter.CounterUnderflow.selector);
        counter.decrement();
    }

    function test_ResetReturnsToZero() public {
        counter.increment();
        counter.increment();
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit Reset(user);
        counter.reset();
        assertEq(counter.count(), 0);
    }
}
