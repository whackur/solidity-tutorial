# Q-12 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q12TxOriginLab` (pre-funded with at least `SEED * N` ETH).
`USER` = user's EOA.

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys vault (5 ETH seeded) + phisher (beneficiary = USER) |
| 2 | view | `LAB` | `phisherOf(USER)` | — | snapshot phisher address |
| 3 | `USER` | `phisher` | `claimFreeAirdrop()` | 0 | phisher calls `vault.transferTo(USER, 5e18)`; tx.origin = USER = vault.owner → passes |
| 4 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Why this drains

The vault gates `transferTo` with `tx.origin == owner`. When the phisher
calls `transferTo`, `msg.sender` is the phisher contract but `tx.origin`
is still USER — the EOA at the bottom of the call stack. The check
passes, and the vault sends its entire balance to wherever the phisher
told it to.

## What the real attack looks like

In production the phisher would be a contract published with an
innocuous-looking UI ("Free NFT mint", "Claim airdrop"). Its constructor
would point `beneficiary` at the attacker's address. The user signs one
tx, and their `tx.origin`-protected wallet contract is drained without
the user ever calling the wallet's `transfer` directly.

## Notes

- `vm.prank(user, user)` is required in tests to set tx.origin as well
  as msg.sender. Plain `vm.prank(user)` leaves tx.origin as the test
  contract's address, which would fail the auth check.
- A *different* attacker (Bob calling the Alice phisher) does NOT drain
  Alice's vault — tx.origin would be Bob, not Alice. So the bug is a
  phishing surface, not a "anyone can drain" hole.
- Each user's vault is independent. Alice's drain does not touch Bob's.
