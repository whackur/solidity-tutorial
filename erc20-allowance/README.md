# erc20-allowance

> The ERC-20 four-function transfer cycle on the smallest possible surface: `transfer` / `approve` / `allowance` / `transferFrom`, demonstrated with a token + a bank that pulls deposits.

## Goals

- Distinguish the two transfer models: `transfer` (holder pushes, 1 call) vs `approve` + `transferFrom` (spender pulls, 2 calls).
- Read `allowance(owner, spender)` as a ledger that is *separate from balances* — enough balance with zero allowance still reverts `transferFrom`.
- Watch the allowance budget decrement as the spender consumes it (`approve(100)` → `deposit(60)` → `allowance == 40`).
- Know the `type(uint256).max` infinite-approval convention — OZ's `_spendAllowance` skips the decrement entirely.

## Files

| File | Topic |
|---|---|
| `src/AllowanceToken.sol` | Minimal OZ ERC20 with a public `mint` so tests can fund accounts freely |
| `src/TokenBank.sol` | The SPENDER side: `deposit` pulls via `transferFrom` (requires prior approve), `withdraw` returns via plain `transfer` |
| `test/AllowanceFlow.t.sol` | Step-by-step walkthrough (a→f): direct transfer → revert without approve → approve → allowance check → decrement → infinite approval → withdraw |

## Key points

- `transferFrom` checks `allowance[from][msg.sender]`, *not* the caller's balance — the spender spends someone else's tokens within a granted budget.
- Without a prior `approve`, `transferFrom` reverts with `ERC20InsufficientAllowance(spender, currentAllowance, needed)` (OZ v5 custom error).
- Every successful `transferFrom` decrements the allowance, *except* when it was set to `type(uint256).max`.
- `withdraw` needs no allowance: the bank owns the tokens it sends back, so a plain `transfer` suffices.
- This is the exact pattern behind every DEX/lending/staking "Approve → Confirm" two-transaction UX.

## Run

```bash
forge build
forge test -vv
```

On-chain practice for the same flow: challenge [`q-20-erc20-basic/`](../q-20-erc20-basic/).
