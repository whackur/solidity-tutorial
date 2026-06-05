// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter internal counter;
    address internal user = address(0xBEEF);

    event Incremented(address indexed by, uint256 newCount);
    event Reset(address indexed by);
    event PersonalIncremented(address indexed by, uint256 newCount);

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

    /*//////////////////////////////////////////////////////////////
                    PERSONAL COUNTER (per msg.sender)
    //////////////////////////////////////////////////////////////*/

    function test_PersonalCountsAreIsolatedPerCaller() public {
        vm.prank(user);
        counter.incrementPersonal();

        assertEq(counter.counts(user), 1);
        assertEq(counter.counts(address(this)), 0);
        // personal ops never touch the shared slot
        assertEq(counter.count(), 0);
    }

    function test_PersonalIncrementEmitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit PersonalIncremented(user, 1);
        counter.incrementPersonal();
    }

    function test_PersonalDecrementRevertsOnUnderflow() public {
        // another caller's balance does not save msg.sender from underflow
        vm.prank(user);
        counter.incrementPersonal();

        vm.expectRevert(Counter.CounterUnderflow.selector);
        counter.decrementPersonal();
    }

    function test_PersonalResetOnlyClearsCallerSlot() public {
        vm.prank(user);
        counter.incrementPersonal();
        counter.incrementPersonal(); // address(this)

        counter.resetPersonal(); // resets address(this) only
        assertEq(counter.counts(address(this)), 0);
        assertEq(counter.counts(user), 1);
    }

    function test_SharedResetWipesEveryone() public {
        vm.prank(user);
        counter.increment();
        counter.increment(); // address(this) — same shared slot

        assertEq(counter.count(), 2);
        counter.reset();
        assertEq(counter.count(), 0); // user's contribution is gone too
    }
}
