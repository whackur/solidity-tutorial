// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q18ReadOnlyLab} from "../src/Setup.sol";

contract Q18ReadOnlyReentrancyPublicTest is Test {
    Q18ReadOnlyLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q18ReadOnlyLab();
        vm.deal(address(lab), 0.1 ether);
        vm.deal(alice, 0.05 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        (address vault, address consumer, address attacker) = lab.createInstance();

        assertTrue(vault != address(0));
        assertTrue(consumer != address(0));
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
