// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q08VoucherChallenge, Q08VoucherToken} from "../src/Setup.sol";

contract Q08VoucherPublicTest is Test {
    Q08VoucherChallenge internal challenge;
    Q08VoucherToken internal token;
    address internal alice = makeAddr("alice");

    function setUp() public {
        challenge = new Q08VoucherChallenge();
        token = challenge.token();
    }

    function test_InitialStateIsUnsolved() public view {
        assertTrue(address(token) != address(0));
        assertFalse(challenge.isSolved(alice));
    }

    function test_DomainSeparatorIsAvailable() public view {
        assertTrue(challenge.domainSeparator() != bytes32(0));
    }
}
