// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q04DelegatecallLab} from "../src/Setup.sol";

contract Q04DelegatecallPublicTest is Test {
    Q04DelegatecallLab internal lab;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        lab = new Q04DelegatecallLab();
    }

    function test_CreateInstanceIsPerUserAndUnsolved() public {
        vm.prank(alice);
        (address aliceCaller, address aliceLogic) = lab.createInstance();
        vm.prank(bob);
        (address bobCaller, address bobLogic) = lab.createInstance();

        assertTrue(aliceCaller != address(0));
        assertTrue(aliceLogic != address(0));
        assertTrue(bobCaller != address(0));
        assertTrue(bobLogic != address(0));
        assertTrue(aliceCaller != bobCaller);
        assertFalse(lab.isSolved(alice));
        assertFalse(lab.isSolved(bob));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
