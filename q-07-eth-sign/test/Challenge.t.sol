// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q07EthSignChallenge} from "../src/Setup.sol";

contract Q07EthSignPublicTest is Test {
    Q07EthSignChallenge internal challenge;
    address internal alice = makeAddr("alice");

    function setUp() public {
        challenge = new Q07EthSignChallenge();
    }

    function test_InitialStateIsUnsolved() public view {
        assertFalse(challenge.isSolved(alice));
    }

    function test_StartChallengeRecordsPerUserPrompt() public {
        vm.prank(alice);
        bytes32 prompt = challenge.startChallenge();

        assertTrue(prompt != bytes32(0));
        assertEq(challenge.challengeOf(alice), prompt);
        assertFalse(challenge.isSolved(alice));
    }
}
