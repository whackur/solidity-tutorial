// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {PermitToken, PermitChallenge} from "../src/Setup.sol";

contract Q06PermitTest is Test {
    PermitToken internal token;
    PermitChallenge internal challenge;

    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;
    address internal recipientA = address(0xA1);
    address internal recipientB = address(0xB2);

    uint256 internal constant VALUE = 100e18;

    bytes32 internal constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");

        token = new PermitToken();
        challenge = new PermitChallenge(token);

        token.mint(alice, VALUE);
        token.mint(bob, VALUE);
    }

    function _signPermit(uint256 pk, address owner, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, address(challenge), value, token.nonces(owner), deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(pk, digest);
    }

    function test_AliceSpendsWithPermit() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alicePk, alice, VALUE, deadline);

        // Anyone may relay the call; here alice submits it herself.
        vm.prank(alice);
        challenge.spendWithPermit(alice, VALUE, deadline, v, r, s, recipientA);

        assertEq(token.balanceOf(recipientA), VALUE, "tokens moved to recipient");
        assertEq(token.balanceOf(alice), 0, "alice drained her balance to recipient");
        assertTrue(challenge.usedPermit(alice));
        assertEq(token.nonces(alice), 1, "permit consumed nonce 0");
        assertTrue(challenge.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 va, bytes32 ra, bytes32 sa) = _signPermit(alicePk, alice, VALUE, deadline);
        (uint8 vb, bytes32 rb, bytes32 sb) = _signPermit(bobPk, bob, VALUE, deadline);

        // Alice's submission first.
        vm.prank(alice);
        challenge.spendWithPermit(alice, VALUE, deadline, va, ra, sa, recipientA);
        assertTrue(challenge.isSolved(alice));
        assertFalse(challenge.isSolved(bob));

        // Bob then submits independently.
        vm.prank(bob);
        challenge.spendWithPermit(bob, VALUE, deadline, vb, rb, sb, recipientB);
        assertTrue(challenge.isSolved(bob));

        assertEq(token.balanceOf(recipientA), VALUE);
        assertEq(token.balanceOf(recipientB), VALUE);
    }

    function test_ReplayBlockedByNonce() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alicePk, alice, VALUE, deadline);

        challenge.spendWithPermit(alice, VALUE, deadline, v, r, s, recipientA);

        vm.expectRevert();
        challenge.spendWithPermit(alice, VALUE, deadline, v, r, s, recipientA);
    }

    function test_RelayerCanSubmit() public {
        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(alicePk, alice, VALUE, deadline);

        address relayer = makeAddr("relayer");
        vm.prank(relayer);
        challenge.spendWithPermit(alice, VALUE, deadline, v, r, s, recipientA);

        // The permit *signer* (alice) gets solve credit, not the relayer.
        assertTrue(challenge.isSolved(alice));
        assertFalse(challenge.isSolved(relayer));
    }
}
