// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// ⚠️  INSTRUCTOR REFERENCE — keep out of student-facing materials.
contract SolutionRef {
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 public constant VOUCHER_TYPEHASH = keccak256(
        "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
    );

    function computeDigest(
        address voucherAddr,
        address token,
        address signer,
        address redeemer,
        uint256 voucherId,
        uint256 amount
    ) external view returns (bytes32 digest) {
        bytes32 domainSep = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("MyEIP712App")),
                keccak256(bytes("1")),
                block.chainid,
                voucherAddr
            )
        );

        bytes32 structHash =
            keccak256(abi.encode(VOUCHER_TYPEHASH, token, signer, redeemer, voucherId, amount));

        digest = keccak256(abi.encodePacked(hex"1901", domainSep, structHash));
    }
}
