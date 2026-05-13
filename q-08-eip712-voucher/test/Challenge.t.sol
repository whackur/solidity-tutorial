// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Voucher, MockERC20} from "../src/Setup.sol";
import {Solution} from "../src/Solution.sol";

contract Q08VoucherTest is Test {
    Voucher internal voucher;
    MockERC20 internal token;
    Solution internal sol;

    address internal signer;
    uint256 internal signerPk;
    address internal redeemer = address(0xCAFE);

    uint256 internal constant AMOUNT = 50e18;

    function setUp() public {
        voucher = new Voucher();
        token = new MockERC20();
        sol = new Solution();

        (signer, signerPk) = makeAddrAndKey("signer");
        token.mint(signer, 1_000e18);
        vm.prank(signer);
        token.approve(address(voucher), type(uint256).max);
    }

    function _sign(uint256 voucherId) internal view returns (bytes memory) {
        bytes32 digest = sol.computeDigest(
            address(voucher), address(token), signer, redeemer, voucherId, AMOUNT
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_RedeemVoucher() public {
        bytes memory sig = _sign(1);
        vm.prank(redeemer);
        voucher.redeemVoucher(address(token), signer, redeemer, 1, AMOUNT, sig);

        assertEq(token.balanceOf(redeemer), AMOUNT, "redeemer received tokens");
        assertTrue(voucher.usedVouchers(1), "voucher marked used");
    }

    function test_ReplayBlocked() public {
        bytes memory sig = _sign(2);

        vm.prank(redeemer);
        voucher.redeemVoucher(address(token), signer, redeemer, 2, AMOUNT, sig);

        vm.prank(redeemer);
        vm.expectRevert(bytes("Voucher already redeemed"));
        voucher.redeemVoucher(address(token), signer, redeemer, 2, AMOUNT, sig);
    }
}
