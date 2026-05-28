// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q06PermitToken, Q06PermitChallenge} from "../src/Setup.sol";

contract Q06PermitPublicTest is Test {
    Q06PermitToken internal token;
    Q06PermitChallenge internal challenge;
    address internal alice = makeAddr("alice");

    function setUp() public {
        token = new Q06PermitToken();
        challenge = new Q06PermitChallenge(token);
        token.mint(alice, 100e18);
    }

    function test_InitialStateIsUnsolved() public view {
        assertEq(token.balanceOf(alice), 100e18);
        assertFalse(challenge.isSolved(alice));
    }

    function test_BadPermitDataIsRejected() public {
        vm.expectRevert();
        challenge.spendWithPermit(alice, 1, block.timestamp + 1, 0, bytes32(0), bytes32(0), address(this));
    }
}
