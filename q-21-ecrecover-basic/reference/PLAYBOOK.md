# Q-21 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q21EcrecoverBasicLab`.
`USER` = user's EOA — does not need any ETH for this challenge.

The deploy script seeds three candidates with index `1` as the trusted one. The lab is intentionally agnostic — any deployment configuration with at least one valid signature will work; the *correct index* is whatever the deployer chose. Instructors using the bundled `Deploy.s.sol` can rely on the index being `1`.

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | view | `LAB` | `trustedSigner()` | — | record the address USER must recover |
| 2 | view | `LAB` | `candidateCount()` | — | typically 3 in the default deploy |
| 3 | view | `LAB` | `candidate(i)` for each `i` | — | grab `(hash, v, r, s)` |
| 4 | off-chain | — | `ecrecover(hash, v, r, s)` per candidate | — | find the one whose recovered address matches trustedSigner |
| 5 | `USER` | `LAB` | `submit(correctIndex)` | 0 | reverts `WrongSigner(recovered)` on mismatch |
| 6 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Off-chain ecrecover helper

`cast wallet verify` does not return the recovered address. Use any of these instead:

```bash
# foundry's cast
cast call "<LAB>" "candidate(uint256)(bytes32,uint8,bytes32,bytes32)" 1
# then plug (hash, v, r, s) into:
cast wallet sig-recover <signature> <messageHash>   # signature = 0x{r}{s}{v}
```

In JS (ethers v6):

```js
const sig = ethers.Signature.from({ r, s, v });
const recovered = ethers.recoverAddress(messageHash, sig);
```

## Mental model

`ecrecover` is *not* asymmetric magic. It is a pure function over `(hash, v, r, s)` that returns the address that must have signed `hash` to produce `(v, r, s)`. Given any *one* of those four inputs is wrong, `ecrecover` returns either a different address or `address(0)`.

## Why this is a separate beginner challenge from q-07 / q-08

- q-07 (eth-sign) extends q-21 by adding the `"\x19Ethereum Signed Message:\n32"` prefix before hashing — students must learn to apply EIP-191 wrapping.
- q-08 (eip712-voucher) extends q-21 by introducing a domain separator and a `keccak256(abi.encode(typeHash, struct...))` digest — students must learn how typed-data hashing layers on top.

A student who has not done q-21 will frequently confuse those wrappers with `ecrecover` *itself*. Start here.

## Common student questions

- **"What does `address(0)` mean?"** — One or more of `v`, `r`, `s` does not encode a valid signature for that hash. Skip that candidate; it is not the right one.
- **"Why is `v` 27 or 28?"** — Historical: Bitcoin originally encoded `recovery_id ∈ {0, 1}` as `27 + recovery_id`. Ethereum kept the convention.
- **"What about EIP-2 / canonical `s`?"** — `ecrecover` accepts any `s`. OpenZeppelin's `ECDSA` library rejects high-`s` signatures because two valid signatures `(r, s)` and `(r, n - s)` exist for the same hash (signature malleability). q-21 stays at the raw level and does not enforce this — the deploy script always produces canonical signatures from `vm.sign`.

## Notes

- `submit()` is permissionless and does *not* mark the user solved on failure; the per-user `_solved[]` slot only flips after a successful `ecrecover` match.
- `_submittedIndex[]` records the last successful submission so the UI can show the user *which* one they identified.
