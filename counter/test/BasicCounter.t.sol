// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test, stdError} from "forge-std/Test.sol";
import {BasicCounter} from "../src/BasicCounter.sol";

contract BasicCounterTest is Test {
    BasicCounter internal counter;

    function setUp() public {
        counter = new BasicCounter();
    }

    function test_InitialCountIsZero() public view {
        assertEq(counter.count(), 0);
    }

    function test_AddIncrementsByOne() public {
        counter.add();
        counter.add();
        counter.add();
        assertEq(counter.count(), 3);
    }

    function test_SubDecrementsByOne() public {
        counter.add();
        counter.add();
        counter.sub();
        assertEq(counter.count(), 1);
    }

    function test_ResetReturnsToZero() public {
        counter.add();
        counter.add();
        counter.reset();
        assertEq(counter.count(), 0);
    }

    function test_SubBelowZeroPanics() public {
        vm.expectRevert(stdError.arithmeticError);
        counter.sub();
    }
}
