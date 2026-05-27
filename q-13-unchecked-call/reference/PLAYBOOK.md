# Q-13 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`ESC` = deployed `Q13UnsafePayout`.
`USER` = user's EOA (needs at least 1 ETH for the deposit).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | view | `ESC` | `trap()` | — | snapshot the per-deploy `Q13RevertOnReceive` helper |
| 2 | `USER` | `ESC` | `deposit()` | `1 ether` | `escrow[USER] = 1e18` |
| 3 | `USER` | `ESC` | `payout(payable)` | 0 | arg = `trap`. `call` reverts inside the trap; `payout` does not propagate. `escrow[USER]=0`, `paidOut[USER]=true`, `stranded[USER]=1e18` |
| 4 | view | `ESC` | `isSolved(USER)` | — | `true` |

## Why this "solves"

The contract has no way to know the ETH never reached `trap`. The
`(bool ok,)` is computed and discarded; the state machine moves on.
The tutorial-grade `stranded` mapping makes the silent failure visible
for grading, but in production code there would be no such mapping —
the bug would just go undetected, money trapped in the contract,
users showing as paid.

## Notes

- `Q13RevertOnReceive` has both `receive()` and `fallback()` reverting,
  so any payment shape (empty calldata, non-empty calldata) fails.
- The bug shape contrasts with q-09 (reentrancy CEI violation) — here
  the state ordering is *correct*, the bug is *return value handling*.
  Reentrancy guards do NOT save this code.
- Each user's escrow is independent. Alice and Bob can both trap
  funds in the contract on their own slots.
