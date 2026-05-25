# Q-20 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Erc20BasicLab`.
`FAUCET` = `LAB.faucet()` (deployed by the lab constructor).
`VAULT` = `LAB.vault()` (deployed by the lab constructor).
`USER` = user's EOA — does not need any ETH for this challenge.

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `FAUCET` | `claim()` | 0 | mints `CLAIM_AMOUNT = 100 MNT` to USER, sets `claimed[USER] = true` |
| 2 | `USER` | `FAUCET` | `approve(VAULT, 25e18)` | 0 | `allowance[USER][VAULT] = 25e18` |
| 3 | `USER` | `VAULT` | `pull(25e18)` | 0 | vault internally calls `FAUCET.transferFrom(USER, VAULT, 25e18)`; consumes the allowance and increments `deposited[USER]` |
| 4 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Mental model

- `transfer` moves *the caller's* tokens.
- `transferFrom` moves *another address's* tokens, but only up to the `allowance` that address has granted to the caller.

```
Step 2:  USER says "VAULT, you may spend up to 25 of my tokens."
         FAUCET.allowance[USER][VAULT] = 25e18

Step 3:  VAULT says "I will move 25 of USER's tokens to myself."
         FAUCET.balanceOf[USER]    -= 25e18
         FAUCET.balanceOf[VAULT]   += 25e18
         FAUCET.allowance[USER][VAULT] -= 25e18  (so it is now 0)
```

If step 2 is skipped, step 3 reverts with `"allowance"`.

## Why this is a separate beginner challenge from q-05 / q-06

q-05 (simple-wallet) wraps ETH deposits and ERC-20 deposits in the same vault. q-06 (erc20-permit) replaces step 2 with a signed `permit()` so the user submits only one transaction. Both build on the *same* approve+transferFrom flow that q-20 isolates here.

If a student does not yet see why a contract cannot "just take" their tokens, walk them through q-20 first and only then bring in q-05 / q-06.

## Common student questions

- **"Why can't I just `transfer(VAULT, 25e18)` instead?"**
  - You can transfer, but the vault's `deposited[]` is only updated inside `pull()`. A direct transfer puts tokens in the vault contract but leaves `deposited[you] == 0`, so `isSolved` stays false. Real protocols often have the same pattern: their accounting requires going through *their* deposit function, which calls `transferFrom` against the allowance you set.
- **"Why is `pull()` permissionless?"**
  - Anyone can *try* to pull, but the allowance is per `(owner, spender)`. The vault is the spender, so its `transferFrom` only succeeds for callers who set `allowance[someone][VAULT] > 0`. The vault then deposits the pulled tokens into `deposited[msg.sender]`, so you only ever credit your own pulls.

## Notes

- The `Faucet` is `MiniERC20` — a hand-rolled, 60-line ERC-20 without OpenZeppelin so beginners can read the entire token implementation in one screen.
- `transferFrom` does short-circuit `allowance == type(uint256).max` (the modern OpenZeppelin convention): an infinite approval is not decremented. With a finite approval (this challenge's case) you can verify the allowance drained to zero after `pull(25e18)`.
