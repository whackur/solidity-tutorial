# Q-22. Spot Price Basic — move an xy=k pool with one swap

> **Difficulty**: Entry ⭐
> **Companion to**: [`q-16-oracle-spot/`](../q-16-oracle-spot/README.md). This is the first contact with constant-product AMM mechanics; q-16 then weaponizes the exact same primitive against a lender that *trusts the spot price* as an oracle.

A single `Q22SpotPriceBasicLab` is deployed. Each user calls `createInstance()` to get their own `Q22MockPool` seeded with `1000 A / 1000 B`, so the starting spot price is `1.0` (1e18). The pool is **tokenless** — there are no ERC-20s and no approvals. Swaps just bump the reserves according to xy=k.

Your job is to swap enough A in to drag the spot price down to `TARGET_PRICE_E18` (`0.5e18`) or below — proving you saw how one trade shifts the "oracle".

## Goal

Make `Q22SpotPriceBasicLab.isSolved(yourAddress)` return `true`. That requires:

1. `poolOf[you]` exists (you called `createInstance()`).
2. `poolOf[you].getSpotPriceE18() <= 0.5e18`.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address pool);
function poolOf(address user) external view returns (Q22MockPool);
function isSolved(address user) external view returns (bool);
uint256 public constant INITIAL_RESERVE = 1_000e18;
uint256 public constant TARGET_PRICE_E18 = 0.5e18;

// Q22MockPool (your personal instance, owner = you)
function swapAForB(uint256 amountIn) external returns (uint256 amountOut); // onlyOwner
function getSpotPriceE18() external view returns (uint256);
function reserveA() external view returns (uint256);
function reserveB() external view returns (uint256);
```

## Student call sequence

1. `lab.createInstance()` — deploys your personal `Q22MockPool(1000e18, 1000e18, you)`.
2. `pool.swapAForB(500e18)` — sends 500 A in; xy=k math leaves reserves at roughly `1500 A / 667 B`, so spot price ≈ `0.444e18`.
3. `lab.isSolved(you)` → `true`.

You can also reach the target with two smaller swaps — xy=k is **path-independent** on reserves, so two 250 swaps end at the same state as one 500.

## The math, in one breath

```
k = reserveA * reserveB                   // constant
newReserveA = reserveA + amountIn
newReserveB = k / newReserveA             // floor division
amountOut   = reserveB - newReserveB
spotPrice   = reserveB / reserveA         // reported scaled by 1e18
```

The spot price is just the *current ratio* of reserves — there is no history, no time-weighting, no second source. Every swap moves it. This is the entire reason single-pool spot prices are unsafe oracles.

## Hints

- The starting spot price is exactly `1e18`. A *tiny* swap moves it a little; the target requires you to shift reserves substantially.
- Try `swapAForB(10e18)` first. Read `getSpotPriceE18()`. Then try `swapAForB(500e18)`. Watch the price drop and the marginal price of further A getting worse (slippage).
- The pool's `swapAForB` is `onlyOwner` — only *your* EOA can move *your* pool's reserves.

## Constraints

- One pool per address. `createInstance` reverts with `"already created"` on a second call.
- Other users' pools are unaffected by your swaps. Cross-user state is impossible by construction.

## Concepts exercised

- **Constant-product AMM (xy=k)**: liquidity is two reserves multiplied; price is their ratio.
- **Slippage**: bigger trades move price worse than smaller ones; the marginal price degrades along the curve.
- **Why spot is a bad oracle**: there is no aggregation. A single trade *is* the price now.
- **Path independence on reserves**: two swaps of 250 leave the pool in the same state as one swap of 500 (ignoring fees, which this mock has none of).

## Where this leads

- [`q-16-oracle-spot/`](../q-16-oracle-spot/README.md) — the same xy=k pool, but now there is a **lender** that quotes loan-to-value using `pool.getSpotPriceE18()`. By swapping into the pool *just before* you borrow, you make the collateral look more valuable than it is, drain the lender, then swap back. The drop in price is no longer an academic exercise.
- The 2021 **Cream Finance** ($130M) and many similar incidents map exactly onto this pattern. q-16 is the live-fire version of q-22.

## Defending it

> **Do not** read a price from a single pool's reserves at transaction time. Use:
>
> - **TWAP** (time-weighted average price) — Uniswap v2/v3 oracles, OpenZeppelin Foundry book chapter on oracles.
> - **Chainlink / Pyth / RedStone** — off-chain aggregated price feeds.
> - **Multi-pool aggregation** with deviation checks.
>
> A spot price *belongs in your UI*, never in your collateral math.
