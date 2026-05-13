// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Setup.sol";

contract Q01CounterTest is Test {
    Counter internal counter;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        counter = new Counter();
    }

    /// @notice Alice solves the challenge end-to-end through a sequence of
    ///         transactions, just like a web UI would.
    function test_AliceSolves() public {
        // 1) Drive Alice's counter to 7 via 7 increment() txs.
        vm.startPrank(alice);
        for (uint256 i = 0; i < 7; ++i) counter.increment();
        vm.stopPrank();
        assertEq(counter.counts(alice), 7, "alice count");

        // 2) Trigger underflow on a fresh second account to observe selector.
        //    (Decrementing alice's counter at 7 wouldn't underflow.)
        //    The web UI student would observe this revert via their wallet's
        //    error toast — we observe it in the test via expectRevert.
        address probe = makeAddr("probe");
        vm.prank(probe);
        vm.expectRevert(Counter.CounterUnderflow.selector);
        counter.decrement();

        // 3) Alice submits the selector she observed.
        vm.prank(alice);
        counter.reportUnderflowSelector(Counter.CounterUnderflow.selector);

        assertTrue(counter.isSolved(alice), "alice solved");
    }

    /// @notice Two users solve in parallel without interfering.
    function test_TwoUsersIndependent() public {
        // Alice gets to 7 the simple way.
        vm.startPrank(alice);
        for (uint256 i = 0; i < 7; ++i) counter.increment();
        counter.reportUnderflowSelector(Counter.CounterUnderflow.selector);
        vm.stopPrank();

        // Bob takes a detour: 8, decrement back to 7.
        vm.startPrank(bob);
        for (uint256 i = 0; i < 8; ++i) counter.increment();
        counter.decrement();
        counter.reportUnderflowSelector(Counter.CounterUnderflow.selector);
        vm.stopPrank();

        assertTrue(counter.isSolved(alice), "alice solved");
        assertTrue(counter.isSolved(bob), "bob solved");
        assertEq(counter.counts(alice), 7, "alice count untouched by bob");
        assertEq(counter.counts(bob), 7, "bob count untouched by alice");
    }

    function test_WrongSelectorRejected() public {
        vm.prank(alice);
        vm.expectRevert();
        counter.reportUnderflowSelector(bytes4(0xdeadbeef));
        assertFalse(counter.sawUnderflow(alice));
    }

    function test_UnderflowRevertSelector() public {
        vm.prank(alice);
        try counter.decrement() {
            revert("decrement should have reverted");
        } catch (bytes memory reason) {
            bytes4 sel = bytes4(reason);
            assertEq(sel, Counter.CounterUnderflow.selector, "expected selector");
        }
    }
}
