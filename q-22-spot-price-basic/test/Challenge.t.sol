// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q22SpotPriceBasicLab} from "../src/Setup.sol";

contract Q22SpotPriceBasicPublicTest is Test {
    Q22SpotPriceBasicLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q22SpotPriceBasicLab();
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address pool = lab.createInstance();

        assertTrue(pool != address(0));
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
