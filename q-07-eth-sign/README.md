# Q-07. ECDSA recovery — eth_sign vs personal_sign

> **Difficulty**: Intermediate ⭐⭐⭐

A single `Q07EthSignChallenge` is deployed. You prove control of your EOA
to it twice: once by signing a per-user 32-byte challenge (eth_sign
style) and once by signing an arbitrary byte string (personal_sign style).
Both signatures must recover to *your own address*.

## Goal

Make `Q07EthSignChallenge.isSolved(yourAddress)` return `true`. Conditions:

- `solvedEthSign[you]` — `submitEthSign(signature)` succeeded against the
  contract's per-user `challengeOf[you]`.
- `solvedPersonalSign[you]` — `submitPersonalSign(message, signature)`
  succeeded against the byte message you signed.

## Contract surface

```solidity
function startChallenge() external returns (bytes32 challenge);
function submitEthSign(bytes calldata signature) external;
function submitPersonalSign(bytes memory message, bytes calldata signature) external;

function challengeOf(address user) external view returns (bytes32);
function solvedEthSign(address user) external view returns (bool);
function solvedPersonalSign(address user) external view returns (bool);
function isSolved(address user) external view returns (bool);
```

## What you can interact with

- A per-user challenge hash, and two signature submission paths.
- One path expects a hash-shaped message, the other expects an arbitrary byte message.

## Hints

- The signing method and the message framing must match the expected digest.
- Wallets often reuse similar UI labels for different byte encodings, so inspect what you are actually signing.
- Both proofs should recover to your own address.

## Constraints

- Do not assume the same signature format works for both paths.
- Keep the exercise scoped to your own wallet identity.

## Why two flavours?

Both use the same EIP-191 prefix `\x19Ethereum Signed Message:\n<len>`:

| Path | `<len>` | Prefix content | Wallet RPC |
|---|---|---|---|
| `eth_sign`-style over a 32-byte hash | `32` | prefix + 32-byte hash | `personal_sign` over the raw hash |
| `personal_sign`-style over bytes | `bytes.length` | prefix + raw bytes | `personal_sign` over the message |

The two encodings are not interchangeable — signing the 32-byte hash
with the *bytes-length* prefix produces a different digest. OZ's
`MessageHashUtils.toEthSignedMessageHash` has overloads for both.

## Concepts exercised

- EIP-191 framing as the wallet-side anti-misuse for `eth_sign`.
- `ECDSA.recover(digest, signature)` to derive the signer from `(r,s,v)`.
- The "challenge → signed proof → on-chain verification" pattern that
  underpins login-via-wallet flows (Sign-In with Ethereum, EIP-4361).
- Why submitting a signature with `recovered != msg.sender` should
  always revert — a missing check is what enables challenge replay.
