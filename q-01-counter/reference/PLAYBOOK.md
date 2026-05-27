# Q-01 — Instructor Playbook

> Ordered transactions a user's web UI would send to reach `isSolved(user) == true`.
> Kept out of student-facing materials.

Assume:

- `COUNTER` = deployed `Q01Counter` address.
- `USER` = user's EOA.

## Steps

| # | From | To | Function | Args | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `COUNTER` | `increment()` | — | bumps `counts[USER]` to 1 |
| 2 | `USER` | `COUNTER` | `increment()` | — | 2 |
| 3 | `USER` | `COUNTER` | `increment()` | — | 3 |
| 4 | `USER` | `COUNTER` | `increment()` | — | 4 |
| 5 | `USER` | `COUNTER` | `increment()` | — | 5 |
| 6 | `USER` | `COUNTER` | `increment()` | — | 6 |
| 7 | `USER` | `COUNTER` | `increment()` | — | 7 — first goal met |
| 8 | `PROBE` | `COUNTER` | `decrement()` | — | from a fresh address whose counter is 0; reverts with `CounterUnderflow()` selector `bytes4(keccak256("CounterUnderflow()"))` |
| 9 | `USER` | `COUNTER` | `reportUnderflowSelector(bytes4)` | `bytes4(keccak256("CounterUnderflow()"))` | second goal met |
| 10 | anyone | `COUNTER` | `isSolved(USER)` (view) | — | returns `true` |

## Notes

- The selector for `error CounterUnderflow()` is `bytes4(keccak256("CounterUnderflow()")) = 0x0c8d3168`.
- Step 8 can also be done from `USER` by first calling `reset()` to zero
  out their own slot, then `decrement()` to reproduce the revert. Skip the
  probe address in that case.
- Auto-grader in `test/Challenge.t.sol` runs this sequence twice (Alice +
  Bob) in parallel to confirm per-user isolation.
