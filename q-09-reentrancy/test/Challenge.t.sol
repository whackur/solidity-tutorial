// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q09ReentrancyLab} from "../src/Setup.sol";

contract Q09ReentrancyPublicTest is Test {
    Q09ReentrancyLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q09ReentrancyLab();
        vm.deal(address(lab), 100 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        (address vault, address attacker) = lab.createInstance();

        assertTrue(vault != address(0));
        assertTrue(attacker != address(0));
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
