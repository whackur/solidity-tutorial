// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q24NftLab} from "../src/Setup.sol";

contract Q24NftOwnershipPublicTest is Test {
    Q24NftLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q24NftLab();
    }

    function test_InitialStateIsUnsolved() public view {
        assertTrue(address(lab.nft()) != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DepositWithoutClaimIsRejected() public {
        vm.prank(alice);
        vm.expectRevert();
        lab.deposit(1);
    }
}
