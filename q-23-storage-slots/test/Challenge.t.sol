// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q23Vault} from "../src/Setup.sol";

contract Q23StorageSlotsPublicTest is Test {
    Q23Vault internal vault;
    address internal alice = makeAddr("alice");

    function setUp() public {
        vault = new Q23Vault(keccak256("a"), keccak256("b"));
    }

    function test_InitialStateIsUnsolved() public view {
        assertFalse(vault.isSolved(alice));
    }

    function test_WrongSubmissionIsRejected() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.submit(bytes32("wrong-a"), bytes32("wrong-b"));
    }
}
