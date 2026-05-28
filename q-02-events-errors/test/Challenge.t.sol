// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q02EventsAndErrors} from "../src/Setup.sol";

contract Q02EventsErrorsPublicTest is Test {
    Q02EventsAndErrors internal challenge;
    address internal alice = makeAddr("alice");

    function setUp() public {
        challenge = new Q02EventsAndErrors();
    }

    function test_InitialStateIsUnsolved() public view {
        assertFalse(challenge.solvedError(alice));
        assertFalse(challenge.solvedPanic(alice));
        assertFalse(challenge.solvedCustom(alice));
        assertFalse(challenge.isSolved(alice));
    }

    function test_WrongSelectorIsRejected() public {
        vm.prank(alice);
        vm.expectRevert();
        challenge.reportErrorSelector(0xffffffff);
    }
}
