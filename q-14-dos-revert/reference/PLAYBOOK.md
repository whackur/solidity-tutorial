# Q-14 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `DosLab`.
`USER` = user's EOA (needs ≥ 0.03 ETH for the two bids).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys (king, attacker); king has no current bid |
| 2 | view | `LAB` | `kingOf(USER)`, `attackerOf(USER)` | — | snapshot addresses |
| 3 | `USER` | `king` | `bid()` | `0.01 ether` | opening bid; `currentKing = USER` |
| 4 | `USER` | `attacker` | `takeThrone()` | `0.02 ether` | forwards `bid(){value:0.02}`; refunds USER 0.01 (OK, EOA); `currentKing = attacker` |
| 5 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Proving the DoS (optional but pedagogically valuable)

After step 4, ANY third-party `king.bid{value: ≥ 0.02 ETH + 1}()` reverts
with `"refund failed"`. The refund call to `attacker.receive()` reverts
inside the attacker, which propagates up through `require(ok, "refund failed")`.

## Why this is the canonical DoS shape

- The pattern is "refund previous user via push payment, require success".
- Anyone who can become the previous user with a reverting receive
  can lock the contract.
- The fix is structural (pull payments), not parameter-tweaking. No
  amount of gas tuning helps — the reverter just costs more, but the
  bid still fails.

## Notes

- The opening EOA bid (step 3) is necessary: without a previous king,
  `bid()` skips the refund branch entirely and the attacker could
  trivially take the throne on the first bid. We force step 3 to
  exercise the refund path in step 4.
- Each user's instance is isolated. Alice can lock her own throne
  without affecting Bob's.
- The attacker is `onlyOwner`. A third party can't trigger someone
  else's takeover.
