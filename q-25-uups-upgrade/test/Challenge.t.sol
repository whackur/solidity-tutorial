// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q25UupsLab} from "../src/Setup.sol";

contract Q25UupsUpgradePublicTest is Test {
    Q25UupsLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q25UupsLab();
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address proxy = lab.createInstance();

        assertTrue(proxy != address(0));
        assertTrue(address(lab.v2Impl()) != address(0));
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
