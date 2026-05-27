# Q-11 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`REG` = deployed `Q11VulnerableRegistry`.
`USER` = user's EOA.

## Steps

| # | From | To | Call | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `REG` | `grantAdmin(address)` | `(USER)` | unguarded setter — passes |
| 2 | `USER` | `REG` | `claimAdmin()` | — | self-only finaliser; sets `solved[USER]` |
| 3 | view | `REG` | `isSolved(USER)` | — | `true` |

## Why two steps

`grantAdmin` is the bug (missing `onlyOwner`), but if `isSolved` keyed
off only `adminPromoted`, anyone could call `grantAdmin(victim)` and
force-solve someone else's challenge. The self-only `claimAdmin()`
shield keeps grading per-user honest.

## Discussion points

- The intended fix is just the missing modifier — show the patched
  version and contrast with `revokeAdmin` which is correctly guarded.
- Mention real incidents: Parity multisig wallet (2017), where
  `initWallet` was unguarded — anyone could re-init and seize ownership.
- Distinguish *missing modifier* (bug) vs *wrong modifier* (e.g.,
  `tx.origin` check) — they look similar but have different attack
  surfaces. The next challenge (q-12 tx-origin) covers the latter.
