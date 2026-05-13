// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {VoucherChallenge, VoucherToken} from "../src/Setup.sol";

contract Q08VoucherTest is Test {
    VoucherChallenge internal challenge;
    VoucherToken internal token;

    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;

    uint256 internal constant AMOUNT = 50e18;

    function setUp() public {
        challenge = new VoucherChallenge();
        token = challenge.token();
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
    }

    function _signVoucher(uint256 pk, address signer, uint256 voucherId, uint256 amount)
        internal
        view
        returns (bytes memory)
    {
        // signer == redeemer for the solo-solve requirement.
        bytes32 digest = challenge.computeDigest(signer, signer, voucherId, amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _solve(address user, uint256 pk, uint256 voucherId) internal {
        bytes memory sig = _signVoucher(pk, user, voucherId, AMOUNT);
        vm.prank(user);
        challenge.redeemVoucher(user, user, voucherId, AMOUNT, sig);
    }

    function test_AliceRedeems() public {
        _solve(alice, alicePk, 1);
        assertEq(token.balanceOf(alice), AMOUNT, "alice received tokens");
        assertTrue(challenge.usedVouchers(1));
        assertTrue(challenge.isSolved(alice));
    }

    function test_TwoUsersIndependent() public {
        _solve(alice, alicePk, 1);
        _solve(bob, bobPk, 2);

        assertTrue(challenge.isSolved(alice));
        assertTrue(challenge.isSolved(bob));
        assertEq(token.balanceOf(alice), AMOUNT);
        assertEq(token.balanceOf(bob), AMOUNT);
    }

    function test_ReplaySameVoucherIdReverts() public {
        _solve(alice, alicePk, 1);
        bytes memory sig = _signVoucher(alicePk, alice, 1, AMOUNT);
        vm.prank(alice);
        vm.expectRevert(bytes("Voucher already redeemed"));
        challenge.redeemVoucher(alice, alice, 1, AMOUNT, sig);
    }

    function test_SignerMustBeRedeemer() public {
        // Alice signs a voucher naming bob as redeemer; bob tries to redeem.
        bytes32 digest = challenge.computeDigest(alice, bob, 3, AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(bob);
        vm.expectRevert(bytes("signer must equal redeemer for solo solve"));
        challenge.redeemVoucher(alice, bob, 3, AMOUNT, sig);
    }

    function test_NonRedeemerCannotSubmit() public {
        bytes memory sig = _signVoucher(alicePk, alice, 4, AMOUNT);
        // bob tries to submit alice's voucher.
        vm.prank(bob);
        vm.expectRevert(bytes("Only the specified redeemer can call this"));
        challenge.redeemVoucher(alice, alice, 4, AMOUNT, sig);
    }

    function test_TamperedAmountReverts() public {
        bytes memory sig = _signVoucher(alicePk, alice, 5, AMOUNT);
        vm.prank(alice);
        vm.expectRevert(bytes("Invalid signature"));
        challenge.redeemVoucher(alice, alice, 5, AMOUNT + 1, sig);
    }
}
