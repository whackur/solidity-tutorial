// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q15FrontRunLab} from "../src/Setup.sol";

contract Q15FrontRunPublicTest is Test {
    Q15FrontRunLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q15FrontRunLab();
        vm.deal(address(lab), 100 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address challenge = lab.createInstance();

        assertTrue(challenge != address(0));
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
