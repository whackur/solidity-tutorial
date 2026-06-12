// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Q15FrontRunLab, Q15FrontRunChallenge, Q15MockToken} from "../src/Setup.sol";

contract Q15FrontRunPublicTest is Test {
    Q15FrontRunLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q15FrontRunLab();
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address challenge = lab.createInstance();

        assertTrue(challenge != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice);
        lab.createInstance();
        vm.expectRevert(bytes("already created"));
        lab.createInstance();
        vm.stopPrank();
    }

    /// @notice Reads the "private" secret straight out of storage slot 1 (the
    ///         on-chain visibility lesson) and claims, proving the tokenized
    ///         version still flips `isSolved` and pays out the prize tokens.
    function test_ReadSecretAndClaim() public {
        vm.prank(alice);
        address challengeAddr = lab.createInstance();
        Q15FrontRunChallenge challenge = Q15FrontRunChallenge(challengeAddr);
        Q15MockToken token = challenge.token();

        assertEq(token.balanceOf(address(challenge)), lab.PRIZE());

        // `private` does not hide storage: slot 1 holds the secret.
        bytes32 secret = vm.load(address(challenge), bytes32(challenge.secretSlot()));

        vm.prank(alice);
        challenge.claim(secret);

        assertTrue(lab.isSolved(alice));
        assertEq(challenge.winner(), alice);
        assertEq(token.balanceOf(alice), lab.PRIZE());
        assertEq(token.balanceOf(address(challenge)), 0);
    }
}
