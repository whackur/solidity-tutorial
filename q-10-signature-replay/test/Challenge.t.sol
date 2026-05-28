// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q10ReplayLab} from "../src/Setup.sol";

contract Q10ReplayPublicTest is Test {
    Q10ReplayLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q10ReplayLab();
        vm.deal(address(lab), 100 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address claim = lab.createInstance(alice);

        assertTrue(claim != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice);
        lab.createInstance(alice);
        vm.expectRevert(bytes("already created"));
        lab.createInstance(alice);
        vm.stopPrank();
    }
}
