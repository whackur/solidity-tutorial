// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q17InflateLab} from "../src/Setup.sol";

contract Q17ReentrancyInflatePublicTest is Test {
    Q17InflateLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q17InflateLab();
        vm.deal(address(lab), 0.1 ether);
        vm.deal(alice, 0.005 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        (address vault, address attacker, address helper) = lab.createInstance();

        assertTrue(vault != address(0));
        assertTrue(attacker != address(0));
        assertTrue(helper != address(0));
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
