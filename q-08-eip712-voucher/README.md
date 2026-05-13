# Q-08. EIP-712 Voucher — build the typed-data digest by hand

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-08-eip712-voucher.md`](../../solidity-tutorial-lecture/docs/challenges/q-08-eip712-voucher.md)
> **Lecture (Korean)**: [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md)
> **Reference source**: [`../eip-712-voucher/src/Voucher.sol`](../eip-712-voucher/src/Voucher.sol)

## Scenario

`Voucher` accepts an EIP-712 signed redemption with:

- Domain: name `"MyEIP712App"`, version `"1"`, chainId, verifyingContract = voucher address.
- Struct:
  ```
  Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)
  ```

Reproduce the digest so the test can sign with `vm.sign` and pass it to `voucher.redeemVoucher(...)`.

## What to implement

```solidity
function computeDigest(
    address voucherAddr,
    address token,
    address signer,
    address redeemer,
    uint256 voucherId,
    uint256 amount
) external view returns (bytes32 digest);
```

## Hints

```solidity
bytes32 EIP712_DOMAIN_TYPEHASH = keccak256(
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
);
bytes32 VOUCHER_TYPEHASH = keccak256(
    "Voucher(address token,address signer,address redeemer,uint256 voucherId,uint256 amount)"
);

bytes32 domainSep = keccak256(abi.encode(
    EIP712_DOMAIN_TYPEHASH,
    keccak256(bytes("MyEIP712App")),
    keccak256(bytes("1")),
    block.chainid,
    voucherAddr
));

bytes32 structHash = keccak256(abi.encode(VOUCHER_TYPEHASH, token, signer, redeemer, voucherId, amount));

digest = keccak256(abi.encodePacked(hex"1901", domainSep, structHash));
```

(OZ `MessageHashUtils.toTypedDataHash(domainSep, structHash)` is the one-liner equivalent.)

## Grading

```bash
forge test -vv
```

- `test_RedeemVoucher` — signing the computed digest lets the redeemer pull tokens.
- `test_ReplayBlocked` — the second redemption with the same `voucherId` reverts.
