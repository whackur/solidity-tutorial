# Q-08. EIP-712 Voucher — sign a typed struct, mint your tokens

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-08-eip712-voucher.md`](../../solidity-tutorial-lecture/docs/challenges/q-08-eip712-voucher.md)
> **Lecture (Korean)**: [PPT 3-4](../../solidity-tutorial-lecture/docs/03-openzeppelin/3-4-eip-712-signatures.md)

A single `VoucherChallenge` (with its own `VoucherToken`) is deployed.
You produce an EIP-712 signature over a `Voucher` struct that names
yourself as both `signer` and `redeemer`, submit it, and the challenge
mints you the requested amount of `VCH`.

## Goal

Make `VoucherChallenge.isSolved(yourAddress)` return `true`. That happens
when you successfully `redeemVoucher(...)` with `signer == redeemer == you`
and a unique `voucherId`.

## Contract surface

```solidity
function redeemVoucher(
    address signer,
    address redeemer,
    uint256 voucherId,
    uint256 amount,
    bytes calldata signature
) external;

function computeDigest(address signer, address redeemer, uint256 voucherId, uint256 amount)
    external view returns (bytes32);   // helper: gives the digest you must sign
function domainSeparator() external view returns (bytes32);
function token() external view returns (VoucherToken);
function usedVouchers(uint256 id) external view returns (bool);
function isSolved(address user) external view returns (bool);
```

## UI call sequence

1. Pick a unique `voucherId` (e.g., `1`). Each id can be redeemed only once globally.
2. Off-chain: sign EIP-712 typed data — exactly:
   ```
   domain: {
     name: "MyEIP712App",
     version: "1",
     chainId,
     verifyingContract: challengeAddress
   }
   types: { Voucher: [token, signer, redeemer, voucherId, amount] }
   message: {
     token:     challenge.token(),
     signer:    you,
     redeemer:  you,
     voucherId: 1,
     amount:    50e18
   }
   ```
   Wallet RPC: `eth_signTypedData_v4`.
3. Submit `challenge.redeemVoucher(you, you, 1, 50e18, signature)` from your wallet.
4. Read `challenge.isSolved(you)` → `true`. Verify `token.balanceOf(you) == 50e18`.

## Guards in play

- `usedVouchers[voucherId]` blocks replay of the same id.
- `msg.sender == redeemer` blocks anyone else from front-running or
  griefing your voucher.
- `signer == redeemer` keeps the challenge solo — each user must sign
  their own voucher (no "instructor minted you a free voucher" path).
- `recoveredSigner == signer` is the EIP-712 signature check itself.

## Concepts exercised

- **EIP-712 typed data**: digest = `keccak256(\x19\x01 || domainSeparator || structHash)`
  where `structHash = keccak256(abi.encode(TYPEHASH, ...fields))`.
- **OpenZeppelin `EIP712` mixin** + `_hashTypedDataV4(structHash)` gives
  you the prefix + domain plumbing without rolling your own.
- **Per-user solo voucher pattern**: a deployment can mint tokens to
  signers without holding pre-funded ETH/allowance — the supply is
  bounded only by the challenge's own logic.
