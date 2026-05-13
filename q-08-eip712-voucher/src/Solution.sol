// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

contract Solution {
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant VOUCHER_TYPEHASH = keccak256(
        "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
    );

    /// @notice Reproduce the EIP-712 digest used by Voucher.redeemVoucher.
    function computeDigest(
        address voucherAddr,
        address token,
        address signer,
        address redeemer,
        uint256 voucherId,
        uint256 amount
    ) external view returns (bytes32 digest) {
        // TODO: build domain separator + struct hash + final 0x1901-prefixed digest.
        //       Hint 1: domain.name = "MyEIP712App", domain.version = "1"
        //       Hint 2: digest = keccak256(abi.encodePacked(hex"1901", domainSep, structHash))
        voucherAddr; token; signer; redeemer; voucherId; amount; digest;
        revert("Solution.computeDigest: not implemented");
    }
}
