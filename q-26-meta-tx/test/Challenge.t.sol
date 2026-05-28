// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q26MyForwarder, Q26MetaCounter} from "../src/Setup.sol";

contract Q26MetaTxPublicTest is Test {
    Q26MyForwarder internal forwarder;
    Q26MetaCounter internal counter;
    address internal alice = makeAddr("alice");

    function setUp() public {
        forwarder = new Q26MyForwarder();
        counter = new Q26MetaCounter(address(forwarder));
    }

    function test_InitialStateIsUnsolved() public view {
        assertEq(counter.trustedForwarder(), address(forwarder));
        assertEq(counter.counterOf(alice), 0);
        assertFalse(counter.isSolved(alice));
    }

    function test_DirectCallIsRejected() public {
        vm.prank(alice);
        vm.expectRevert(Q26MetaCounter.MustGoThroughForwarder.selector);
        counter.increment();
    }
}
