# Q-22 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q22SpotPriceBasicLab`.
`USER` = user's EOA — does not need any ETH for this challenge.

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys Q22MockPool with 1000:1000 reserves, owner = USER |
| 2 | view | `LAB` | `poolOf(USER)` | — | grab pool address |
| 3 | view | pool | `getSpotPriceE18()` | — | starts at exactly `1e18` |
| 4 | `USER` | pool | `swapAForB(500e18)` | 0 | xy=k: reserves go to ~1500 A / ~667 B, spot ≈ `0.444e18` |
| 5 | view | pool | `getSpotPriceE18()` | — | now `<= 0.5e18` |
| 6 | view | `LAB` | `isSolved(USER)` | — | `true` |

## The math, worked out

```
k             = 1000 * 1000 = 1_000_000   (in e18 squared)
newReserveA   = 1000 + 500  = 1500
newReserveB   = k / newReserveA = floor(1_000_000 / 1500) = 666.66...
amountOutB    = 1000 - newReserveB = 333.33...
newSpotPrice  = newReserveB / newReserveA = 0.4444...
```

If we want spot exactly at `0.5e18`:

```
spot     = B/A = 0.5
A * B    = 1_000_000
=> A * 0.5 * A = 1_000_000
=> A = sqrt(2_000_000) ≈ 1414.2
=> amountIn ≈ 414.2
```

So any swap of ~415 or more clears the threshold. The tests use 500 for safe margin.

## Why this is a separate beginner challenge from q-16

q-16 requires a student to (a) understand xy=k, (b) understand that a lender quoting spot is dangerous, and (c) wire a manipulate → borrow → swap-back sequence. That is too many new ideas at once. q-22 isolates *just* (a) so the student can come back to q-16 with the price math already in their head.

## Common student questions

- **"Where do the tokens come from? I didn't approve anything."**
  - The mock pool has no underlying ERC-20s. Reserves are just counters. The student gets to watch *only* the price mechanic, no token plumbing.
- **"Why is the new spot lower than 0.5 with a swap of 500?"**
  - xy=k: the curve gets steeper as one reserve grows. 500 A pushes reserveA past the breakeven point of 1414, so spot lands at ~0.444 — below the 0.5 target.
- **"Can I swap in two smaller pieces?"**
  - Yes. xy=k is path-independent on reserves. Two swaps of 250 land at the same state as one swap of 500. (Real AMMs charge a per-swap fee, so in production splitting helps and hurts at the same time.)

## Notes

- `swapAForB` is `onlyOwner` so only the pool's user can manipulate their own pool. Cross-user interference is impossible.
- No fees, no minimum-out check, no slippage protection — the focus is the price math.
- `getSpotPriceE18()` uses unchecked-style integer math because `reserveA` and `reserveB` never reach zero on this lab (the constructor enforces `> 0` and xy=k preserves non-zero reserves).
