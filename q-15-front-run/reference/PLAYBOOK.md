# Q-15 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `FrontRunLab` (pre-funded with at least `PRIZE * N` ETH).
`USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | — | deploys per-user challenge, seeds `1 ETH`, sets `_secret = keccak(USER, ts, prevrandao, nonce)` |
| 2 | view | `LAB` | `challengeOf(USER)` | — | snapshot challenge address |
| 3 | off-chain | RPC | `eth_getStorageAt(challenge, 0x01)` | — | returns the 32-byte secret |
| 4 | `USER` | `challenge` | `claim(bytes32)` | `(secret)` | wins; prize forwarded to USER |
| 5 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Storage layout reminder

| Slot | Field | Type |
|---|---|---|
| 0 | `owner` | `address` (right-aligned, leading zeroes) |
| 1 | `_secret` | `bytes32` (read this) |
| 2 | `winner` | `address` |

`secretSlot()` is published as `pure returns (1)` for student tooling.

## viem reference

```ts
const challenge = await publicClient.readContract({
  address: LAB,
  abi: labAbi,
  functionName: 'challengeOf',
  args: [USER],
});
const secret = await publicClient.getStorageAt({
  address: challenge,
  slot: 1n,
});
await walletClient.writeContract({
  address: challenge,
  abi: challengeAbi,
  functionName: 'claim',
  args: [secret],
});
```

## Why front-running is included even though this is "read storage, not mempool"

The lesson generalises. The bug shape "the secret is somewhere a third
party can see before the privileged actor uses it" applies to:

- `private` storage (this challenge)
- public mempool tx calldata (classic front-running)
- public on-chain commitments without time delay
- leaked logs from a related contract

Distinguishing the channels (storage vs mempool vs logs) is secondary;
the fix is always: don't put the secret somewhere observable, or
commit-reveal it.

## Notes

- The lab uses `block.prevrandao + block.timestamp + caller + nonce`
  to seed the secret. In a real production deploy this would be a
  signer-only off-chain source. We don't need real entropy here; we
  just need each user to get a distinct secret.
- The "third party front-runs Alice" test (`test_ThirdPartyCanFrontRun`)
  intentionally lets Bob steal Alice's prize to demonstrate the bug
  shape end-to-end. The grader only checks the user's own slot.
