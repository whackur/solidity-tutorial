// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q16OracleLab} from "../src/Setup.sol";

contract Q16OracleSpotPublicTest is Test {
    Q16OracleLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q16OracleLab();
        vm.deal(address(lab), 100 ether);
        vm.deal(alice, 5 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        (address token, address pool, address lender) = lab.createInstance();

        assertTrue(token != address(0));
        assertTrue(pool != address(0));
        assertTrue(lender != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
