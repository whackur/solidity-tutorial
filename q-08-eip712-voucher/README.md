# Q-08. EIP-712 Voucher — sign a typed struct, mint your tokens

> **Difficulty**: Intermediate ⭐⭐⭐

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

## What you can interact with

- A voucher redemption function that validates an EIP-712 signature.
- A token contract that mints the reward when the voucher is accepted.

## Hints

- The typed data must line up with the challenge's domain and the voucher fields.
- Use a unique voucher identifier so the replay guard does not interfere.
- The signer and redeemer roles are intentionally kept simple for this exercise.

## Constraints

- Sign only for the instance you are working on.
- The lesson is structured signing, not hidden calldata tricks.

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
