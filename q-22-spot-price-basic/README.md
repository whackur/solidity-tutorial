# Q-22. Spot Price Basic — move an xy=k pool

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

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

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

- The starting spot price is exactly `1e18`. A tiny swap moves it a little; the target requires a meaningful reserve shift.
- Compare small and large `swapAForB` inputs while reading `getSpotPriceE18()`. Watch the marginal price of further A get worse (slippage).
- The pool's `swapAForB` is `onlyOwner` — only *your* EOA can move *your* pool's reserves.

## Constraints

- One pool per address. `createInstance` reverts with `"already created"` on a second call.
- Other users' pools are unaffected by your swaps. Cross-user state is impossible by construction.

## Concepts exercised

- **Constant-product AMM (xy=k)**: liquidity is two reserves multiplied; price is their ratio.
- **Slippage**: bigger trades move price worse than smaller ones; the marginal price degrades along the curve.
- **Why spot is a bad oracle**: there is no aggregation. A single trade *is* the price now.
- **Path independence on reserves**: with no fees, only the final reserve state matters.

## Where this leads

- [`q-16-oracle-spot/`](../q-16-oracle-spot/README.md) — the same xy=k pool becomes part of a lending decision, which turns spot-price movement into a security issue.
- The 2021 **Cream Finance** ($130M) and many similar incidents map exactly onto this pattern. q-16 is the live-fire version of q-22.

## Defending it

> **Do not** read a price from a single pool's reserves at transaction time. Use:
>
> - **TWAP** (time-weighted average price) — Uniswap v2/v3 oracles, OpenZeppelin Foundry book chapter on oracles.
> - **Chainlink / Pyth / RedStone** — off-chain aggregated price feeds.
> - **Multi-pool aggregation** with deviation checks.
>
> A spot price *belongs in your UI*, never in your collateral math.
