// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Q07EthSignChallenge} from "../src/Setup.sol";

contract Q07EthSignTest is Test {
    Q07EthSignChallenge internal sig;

    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;

    function setUp() public {
        sig = new Q07EthSignChallenge();
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
    }

    function _sig(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _solveEthSign(address user, uint256 pk) internal {
        vm.prank(user);
        sig.startChallenge();
        bytes32 ch = sig.challengeOf(user);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(ch);
        bytes memory signature = _sig(pk, digest);
        vm.prank(user);
        sig.submitEthSign(signature);
    }

    function _solvePersonalSign(address user, uint256 pk, bytes memory message) internal {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(message);
        bytes memory signature = _sig(pk, digest);
        vm.prank(user);
        sig.submitPersonalSign(message, signature);
    }

    function test_AliceSolvesBoth() public {
        _solveEthSign(alice, alicePk);
        _solvePersonalSign(alice, alicePk, bytes("hello, personal_sign world!"));
        assertTrue(sig.solvedEthSign(alice));
        assertTrue(sig.solvedPersonalSign(alice));
        assertTrue(sig.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solveEthSign(alice, alicePk);
        _solvePersonalSign(alice, alicePk, bytes("alice's note"));

        _solveEthSign(bob, bobPk);
        _solvePersonalSign(bob, bobPk, bytes("bob's note"));

        assertTrue(sig.isSolved(alice));
        assertTrue(sig.isSolved(bob));
        // Each user gets their own challenge.
        assertTrue(sig.challengeOf(alice) != bytes32(0));
        assertTrue(sig.challengeOf(bob) != bytes32(0));
    }

    function test_EthSignWithWrongKeyReverts() public {
        vm.prank(alice);
        sig.startChallenge();
        bytes32 ch = sig.challengeOf(alice);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(ch);
        bytes memory signature = _sig(bobPk, digest); // bob's signature for alice's challenge

        vm.prank(alice);
        vm.expectRevert(bytes("signature must be from msg.sender"));
        sig.submitEthSign(signature);
    }

    function test_MissingChallengeReverts() public {
        bytes32 anyHash = keccak256("nope");
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(anyHash);
        bytes memory signature = _sig(alicePk, digest);

        vm.prank(alice);
        vm.expectRevert(bytes("no challenge - call startChallenge first"));
        sig.submitEthSign(signature);
    }

    function test_PersonalSignWithWrongKeyReverts() public {
        bytes memory message = bytes("hello");
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(message);
        bytes memory signature = _sig(bobPk, digest);

        vm.prank(alice);
        vm.expectRevert(bytes("signature must be from msg.sender"));
        sig.submitPersonalSign(message, signature);
    }

    function test_ChallengeRerollsOnRestart() public {
        vm.prank(alice);
        sig.startChallenge();
        bytes32 firstChallenge = sig.challengeOf(alice);

        // Advance time/randomness to force a different hash.
        vm.warp(block.timestamp + 1);
        vm.prevrandao(bytes32(uint256(123456)));

        vm.prank(alice);
        sig.startChallenge();
        bytes32 secondChallenge = sig.challengeOf(alice);
        assertTrue(firstChallenge != secondChallenge);
    }
}
