// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q13UnsafePayout} from "../src/Setup.sol";

contract Q13UncheckedCallPublicTest is Test {
    Q13UnsafePayout internal escrow;
    address internal alice = makeAddr("alice");

    function setUp() public {
        escrow = new Q13UnsafePayout();
        vm.deal(alice, 1 ether);
    }

    function test_InitialStateIsUnsolved() public view {
        assertTrue(address(escrow.trap()) != address(0));
        assertFalse(escrow.isSolved(alice));
    }

    function test_DepositAloneDoesNotSolve() public {
        vm.prank(alice);
        escrow.deposit{value: 1 wei}();

        assertEq(escrow.escrow(alice), 1 wei);
        assertFalse(escrow.isSolved(alice));
    }
}
