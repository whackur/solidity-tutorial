# Q-21. Ecrecover Basic — recover a signer from `(hash, v, r, s)`

> **Difficulty**: Entry ⭐
> **Companion to**: [`q-07-eth-sign/`](../q-07-eth-sign/README.md) and [`q-08-eip712-voucher/`](../q-08-eip712-voucher/README.md). This is the first contact with the raw `ecrecover` primitive; q-07 then adds the EIP-191 `\x19Ethereum Signed Message:\n` prefix, and q-08 adds an EIP-712 domain separator on top.

A single `EcrecoverBasicLab` is deployed. The lab publishes a fixed set of *candidate signatures* — each candidate is a tuple `(messageHash, v, r, s)`. Exactly **one** of them was signed by `trustedSigner` (a public, immutable address on the lab). The other candidates were signed by random impostor keys.

Your job is to identify which candidate index recovers to `trustedSigner` and submit it. No on-chain hashing tricks — the raw `keccak256(message)` is already on the lab as `messageHash`.

## Goal

Make `EcrecoverBasicLab.isSolved(yourAddress)` return `true`. That requires one `submit(uint256 index)` call where `ecrecover(messageHash, v, r, s) == trustedSigner` for that index.

## Contract surface

```solidity
function trustedSigner() external view returns (address);
function candidateCount() external view returns (uint256);
function candidate(uint256 i) external view returns (bytes32 messageHash, uint8 v, bytes32 r, bytes32 s);
function submit(uint256 index) external;          // reverts WrongSigner(recovered) on mismatch
function submittedIndex(address user) external view returns (uint256);
function isSolved(address user) external view returns (bool);
```

## Student call sequence

1. Read `trustedSigner()` and `candidateCount()`.
2. For each index `i` in `0..candidateCount-1`:
   - Read `candidate(i)` → `(hash, v, r, s)`.
   - Compute `ecrecover(hash, v, r, s)` off-chain (web UI, `cast`, viem, ethers, anything).
3. Pick the index whose recovered address equals `trustedSigner`.
4. Call `submit(thatIndex)`.
5. `isSolved(you)` → `true`.

## What you can interact with

- All candidate tuples are public. Reading is free.
- `submit` is permissionless; if you submit the wrong index it reverts with `WrongSigner(recovered)` so you can see *who* signed the wrong candidate — useful learning, not a leak.

## Hints

- `ecrecover` is a precompile at address `0x01`. It takes the *exact* `bytes32` hash you already have on `candidate(i).messageHash` — no further hashing required.
- `v` is `27` or `28` for standard secp256k1 signatures on Ethereum.
- If `ecrecover` returns `address(0)` for an entry, the signature is malformed for that hash — that candidate cannot be the right one.

## Constraints

- Submitting the wrong index reverts. Your per-user state stays unchanged on a revert, so you can keep trying.
- Two users solving in parallel do not interfere — `_solved[]` and `_submittedIndex[]` are keyed by `msg.sender`.

## Concepts exercised

- **`ecrecover(hash, v, r, s) -> signer`** as the only signature primitive on the EVM.
- **Why three pieces `(v, r, s)`**: `r` and `s` are the ECDSA point/scalar; `v` disambiguates which of two possible recovered public keys is intended.
- **Why a hash, not a message**: ECDSA signs a 32-byte digest. Whatever wrapping comes later (EIP-191 prefix, EIP-712 typed data) is *just a recipe for computing that digest*.
- **Why publishing `(hash, signature)` is safe**: anyone can verify, no one can forge — the signature is bound to that exact `hash` and to whoever owns the private key.

## Where this leads

- [`q-07-eth-sign/`](../q-07-eth-sign/README.md) — same `ecrecover`, but the hash is wrapped with `"\x19Ethereum Signed Message:\n32"` (the `eth_sign` / `personal_sign` standard) before signing.
- [`q-08-eip712-voucher/`](../q-08-eip712-voucher/README.md) — same `ecrecover`, but the hash is built from a typed-data domain separator and a struct hash so wallets can show the user a *meaningful* signing prompt.
- [`q-10-signature-replay/`](../q-10-signature-replay/README.md) — once you can verify a signature, what happens if there is no nonce to bind it to a single use?
