// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {Voucher} from "../src/Voucher.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract VoucherTest is Test {
    bytes32 internal constant VOUCHER_TYPEHASH = keccak256(
        "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
    );

    Voucher internal voucher;
    MyERC20 internal token;

    uint256 internal signerKey;
    address internal signer;
    address internal redeemer = address(0xBEEF);
    address internal otherAccount = address(0xCAFE);

    uint256 internal constant VOUCHER_ID = 1;
    uint256 internal constant AMOUNT = 100;

    function setUp() public {
        signerKey = 0xA11CE;
        signer = vm.addr(signerKey);

        token = new MyERC20("My Test Token", "MTT", 1_000_000);
        voucher = new Voucher();

        // Move funds to signer so transferFrom can succeed
        token.transfer(signer, AMOUNT * 10);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("MyEIP712App")),
                keccak256(bytes("1")),
                block.chainid,
                address(voucher)
            )
        );
    }

    function _signVoucher(uint256 pk, address tokenAddr, address voucherSigner, address voucherRedeemer)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(VOUCHER_TYPEHASH, tokenAddr, voucherSigner, voucherRedeemer, VOUCHER_ID, AMOUNT)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_Deployment() public view {
        assertTrue(address(voucher) != address(0));
    }

    function test_RedeemValidVoucher() public {
        bytes memory sig = _signVoucher(signerKey, address(token), signer, redeemer);

        vm.prank(signer);
        token.approve(address(voucher), AMOUNT);

        uint256 redeemerBefore = token.balanceOf(redeemer);

        vm.prank(redeemer);
        voucher.redeemVoucher(address(token), signer, redeemer, VOUCHER_ID, AMOUNT, sig);

        assertTrue(voucher.usedVouchers(VOUCHER_ID));
        assertEq(token.balanceOf(redeemer), redeemerBefore + AMOUNT);
    }

    function test_RevertWhen_SignatureInvalid() public {
        uint256 wrongKey = 0xB0B;
        bytes memory sig = _signVoucher(wrongKey, address(token), signer, redeemer);

        vm.prank(redeemer);
        vm.expectRevert(bytes("Invalid signature"));
        voucher.redeemVoucher(address(token), signer, redeemer, VOUCHER_ID, AMOUNT, sig);
    }

    function test_RevertWhen_VoucherAlreadyRedeemed() public {
        bytes memory sig = _signVoucher(signerKey, address(token), signer, redeemer);

        vm.prank(signer);
        token.approve(address(voucher), AMOUNT * 2);

        vm.prank(redeemer);
        voucher.redeemVoucher(address(token), signer, redeemer, VOUCHER_ID, AMOUNT, sig);

        vm.prank(redeemer);
        vm.expectRevert(bytes("Voucher already redeemed"));
        voucher.redeemVoucher(address(token), signer, redeemer, VOUCHER_ID, AMOUNT, sig);
    }

    function test_RevertWhen_CallerIsNotRedeemer() public {
        bytes memory sig = _signVoucher(signerKey, address(token), signer, redeemer);

        vm.prank(otherAccount);
        vm.expectRevert(bytes("Only the specified redeemer can call this"));
        voucher.redeemVoucher(address(token), signer, redeemer, VOUCHER_ID, AMOUNT, sig);
    }
}
