// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q14DosLab} from "../src/Setup.sol";

contract Q14DosRevertPublicTest is Test {
    Q14DosLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q14DosLab();
        vm.deal(alice, 1 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        (address king, address helper) = lab.createInstance();

        assertTrue(king != address(0));
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
