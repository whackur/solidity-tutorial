// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q03EthMailbox} from "../src/Setup.sol";

contract Q03MailboxPublicTest is Test {
    Q03EthMailbox internal mailbox;
    address internal alice = makeAddr("alice");

    function setUp() public {
        mailbox = new Q03EthMailbox();
        vm.deal(alice, 1 ether);
    }

    function test_InitialStateIsUnsolved() public view {
        assertFalse(mailbox.hitReceive(alice));
        assertFalse(mailbox.hitFallback(alice));
        assertFalse(mailbox.hitReceivePayable(alice));
        assertFalse(mailbox.isSolved(alice));
    }

    function test_OneEntryPointDoesNotSolve() public {
        vm.prank(alice);
        (bool ok,) = address(mailbox).call{value: 1 wei}("");
        assertTrue(ok);

        assertTrue(mailbox.hitReceive(alice));
        assertFalse(mailbox.isSolved(alice));
    }
}
