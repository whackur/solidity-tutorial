// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q12TxOriginLab} from "../src/Setup.sol";

contract Q12TxOriginPublicTest is Test {
    Q12TxOriginLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q12TxOriginLab();
        vm.deal(address(lab), 100 ether);
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice, alice);
        (address vault, address phisher) = lab.createInstance();

        assertTrue(vault != address(0));
        assertTrue(phisher != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice, alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }
}
