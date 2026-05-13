# Q-17 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `InflateLab` (pre-funded with at least `SEED * N` ETH).
`USER` = user's EOA (needs ≥ 1 ETH bait).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys (vault, attacker, helper); lab calls `vault.deposit{value:1e18}()` so `balances[LAB] = 1e18` |
| 2 | view | `LAB` | `attackerOf(USER)`, `helperOf(USER)` | — | snapshot addresses |
| 3 | `USER` | `attacker` | `attack()` | `1 ether` | deposits + outer withdraw + cross-function transfer (see trace below) |
| 4 | `USER` | `helper` | `pull()` | 0 | helper's `withdraw()` sends the cross-transferred balance back out |
| 5 | view | `LAB` | `isSolved(USER)` | — | `true` |

## Reentrancy trace

```
USER -> attacker.attack{value:1e18}
  attacker -> vault.deposit{value:1e18}
    balances[attacker] = 1e18
  attacker -> vault.withdraw()
    bal = balances[attacker] = 1e18
    vault.call{value:1e18}(attacker)               // sends 1e18 to attacker
      attacker.receive() fires (in attack mode)
      attacker -> vault.transferBalance(helper, 1e18)
        balances[attacker] = 0
        balances[helper]   = 1e18
      receive() returns
    balances[attacker] = 0                          // already 0; no-op

USER -> helper.pull()
  helper -> vault.withdraw()
    bal = balances[helper] = 1e18
    vault.call{value:1e18}(helper)                  // sends 1e18 to helper
    balances[helper] = 0
```

Vault drained from 2 ETH to 0. Attacker contract holds 1 ETH, helper
contract holds 1 ETH. Net: USER deposited 1 ETH (the bait) and ended
up controlling 2 ETH across the two contracts — `+1 ETH = SEED`.

## Why this drains

- The bug is *cross-function* CEI violation: `withdraw` writes
  `balances[msg.sender]` *after* an external call, AND another mutator
  (`transferBalance`) reads/writes the same map.
- A single-function reentrancy guard on `withdraw` would NOT save it —
  the re-entry lands in `transferBalance`, a different function.
- Single-deposit double-payout: the vault paid the same 1 ETH balance
  out twice, once to attacker and once to helper. Total drained > total
  deposited.

## Notes

- `attacker.attack` and `helper.pull` are `onlyOwner`. A third party
  can't trigger someone else's inflate.
- `_attacking` flag inside `InflateAttacker.receive()` prevents the
  re-entry from looping past one hop — we need exactly one cross-function
  transfer, not a recursion.
- Each user's instance is isolated. Alice and Bob can both inflate
  simultaneously without affecting each other.
