// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q02EventsAndErrors} from "../src/Setup.sol";

contract Q02EventsErrorsTest is Test {
    Q02EventsAndErrors internal e;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        e = new Q02EventsAndErrors();
    }

    function test_RequireRevertsAsErrorString() public {
        try e.failWithRequire(0) {
            revert("must have reverted");
        } catch (bytes memory reason) {
            bytes4 sel = bytes4(reason);
            assertEq(sel, bytes4(0x08c379a0), "Error(string) selector");
        }
    }

    function test_AssertRevertsAsPanic() public {
        try e.failWithAssert(false) {
            revert("must have reverted");
        } catch (bytes memory reason) {
            bytes4 sel = bytes4(reason);
            assertEq(sel, bytes4(0x4e487b71), "Panic(uint256) selector");
        }
    }

    function test_CustomErrorRevertsWithCustomSelector() public {
        try e.failWithCustomError(1, 2) {
            revert("must have reverted");
        } catch (bytes memory reason) {
            bytes4 sel = bytes4(reason);
            assertEq(
                sel, Q02EventsAndErrors.InsufficientBalance.selector, "InsufficientBalance selector"
            );
        }
    }

    function test_AliceSolvesAll() public {
        vm.startPrank(alice);
        e.reportErrorSelector(bytes4(0x08c379a0));
        e.reportPanicSelector(bytes4(0x4e487b71));
        e.reportCustomSelector(Q02EventsAndErrors.InsufficientBalance.selector);
        vm.stopPrank();

        assertTrue(e.isSolved(alice), "alice solved");
    }

    function test_TwoUsersIndependent() public {
        vm.startPrank(alice);
        e.reportErrorSelector(bytes4(0x08c379a0));
        e.reportPanicSelector(bytes4(0x4e487b71));
        e.reportCustomSelector(Q02EventsAndErrors.InsufficientBalance.selector);
        vm.stopPrank();

        // Bob has only done two of three.
        vm.startPrank(bob);
        e.reportErrorSelector(bytes4(0x08c379a0));
        e.reportPanicSelector(bytes4(0x4e487b71));
        vm.stopPrank();

        assertTrue(e.isSolved(alice), "alice solved");
        assertFalse(e.isSolved(bob), "bob not yet solved");

        // Bob finishes.
        vm.prank(bob);
        e.reportCustomSelector(Q02EventsAndErrors.InsufficientBalance.selector);
        assertTrue(e.isSolved(bob), "bob now solved");
    }

    function test_WrongSelectorReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        e.reportErrorSelector(bytes4(0xdeadbeef));
    }
}
