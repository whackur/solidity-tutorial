// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q20Erc20BasicLab} from "../src/Setup.sol";

contract Q20Erc20BasicPublicTest is Test {
    Q20Erc20BasicLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q20Erc20BasicLab();
    }

    function test_InitialStateIsUnsolved() public view {
        assertTrue(address(lab.faucet()) != address(0));
        assertTrue(address(lab.vault()) != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_PublicConstantsAreNonZero() public view {
        assertGt(lab.TARGET(), 0);
        assertGt(lab.faucet().CLAIM_AMOUNT(), 0);
    }
}
