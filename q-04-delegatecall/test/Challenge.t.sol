// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q04DelegatecallLab, Q04DelegateCaller, Q04DelegateLogic} from "../src/Setup.sol";

contract Q04DelegatecallTest is Test {
    Q04DelegatecallLab internal lab;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q04DelegatecallLab();
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
    }

    function _solve(address user) internal {
        vm.startPrank(user);
        lab.createInstance();
        Q04DelegateCaller caller = lab.callerOf(user);
        Q04DelegateLogic logic = lab.logicOf(user);

        // call: writes to logic.storage
        caller.setVarsViaCall{value: 1 ether}(logic, 42);

        // delegatecall: writes to caller.storage (logic code executed in caller's context)
        caller.setVarsViaDelegatecall{value: 1 ether}(address(logic), 99);
        vm.stopPrank();
    }

    function test_AliceSolves() public {
        _solve(alice);
        assertEq(lab.logicOf(alice).number(), 42, "logic.number via call");
        assertEq(lab.callerOf(alice).number(), 99, "caller.number via delegatecall");
        assertTrue(lab.isSolved(alice), "alice solved");
    }

    function test_SenderPreservedThroughDelegatecall() public {
        vm.prank(alice);
        lab.createInstance();
        Q04DelegateCaller caller = lab.callerOf(alice);
        Q04DelegateLogic logic = lab.logicOf(alice);

        vm.prank(alice);
        caller.setVarsViaDelegatecall(address(logic), 7);

        // delegatecall preserves msg.sender from the outer call (alice's EOA).
        assertEq(caller.sender(), alice, "delegatecall preserves alice as msg.sender");
        assertEq(logic.sender(), address(0), "logic.sender untouched");
    }

    function test_TwoUsersIndependent() public {
        _solve(alice);
        _solve(bob);
        assertTrue(lab.isSolved(alice), "alice solved");
        assertTrue(lab.isSolved(bob), "bob solved");

        // Independent instances.
        assertTrue(lab.callerOf(alice) != lab.callerOf(bob), "different caller instances");
        assertTrue(lab.logicOf(alice) != lab.logicOf(bob), "different logic instances");
    }

    function test_PartialProgressDoesNotSolve() public {
        vm.startPrank(alice);
        lab.createInstance();
        Q04DelegateCaller caller = lab.callerOf(alice);
        Q04DelegateLogic logic = lab.logicOf(alice);
        caller.setVarsViaCall{value: 1 ether}(logic, 42);
        vm.stopPrank();
        assertFalse(lab.isSolved(alice), "needs delegatecall too");
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
