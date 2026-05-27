# Q-09 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q09ReentrancyLab` (pre-funded with at least `SEED * N` ETH).
`USER` = user's EOA (needs at least 1 ETH for the bait).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys `(vault, attacker)` for USER; lab calls `vault.deposit{value: 10e18}()` so `balances[lab] = 10e18` |
| 2 | view | `LAB` | `attackerOf(USER)` | — | snapshot personal attacker address |
| 3 | `USER` | `attacker` | `attack()` | `1 ether` | attacker deposits 1 ETH then calls `vault.withdraw()`; vault's external call lands in `attacker.receive()`, which re-enters `withdraw()` repeatedly until `vault.balance < attackAmount` |
| 4 | view | `LAB` | `isSolved(USER)` | — | `true` (vault drained, attacker holds ≥ 10 ETH) |
| 5 | `USER` | `attacker` | `drain()` (optional) | — | forwards all stolen ETH to USER's EOA |

## Pre-deploy funding

```solidity
Q09ReentrancyLab lab = new Q09ReentrancyLab();
vm.deal(address(lab), 100 ether);   // tutorial setup; 10 users at SEED=10 ETH each
```

On testnet the deployer can fund the lab via a normal ETH transfer
(empty calldata) — the lab has `receive() external payable {}`.

## Mechanics of the drain (re-entrancy trace)

```
USER -> attacker.attack{value: 1e18}
  attacker -> vault.deposit{value: 1e18}    // balances[attacker] = 1e18
  attacker -> vault.withdraw()
    vault: bal = balances[attacker] = 1e18
    vault.call{value: 1e18}(attacker)        // sends 1e18 to attacker
      attacker.receive() runs
      attacker -> vault.withdraw()           // re-entry!
        vault: bal = balances[attacker] = 1e18 (still!)
        vault.call{value: 1e18}(attacker)    // sends another 1e18
          attacker.receive() ... and so on, ~10 iterations until
          vault.balance < 1e18, then receive() stops re-entering
        balances[attacker] = 0
      balances[attacker] = 0 (already zero — harmless)
    balances[attacker] = 0 (already zero — harmless)
```

Each user's vault is independent — alice's attack does not touch bob's
vault, so two users can run the attack concurrently.

## Notes

- `attacker.attack(...)` is `onlyOwner` so a third party can't trigger
  someone else's attacker. This prevents an outsider from "solving" a
  challenge for a user.
- `createInstance()` reverts with `"already created"` if USER already
  has a pair. Reset would require redeploying the lab.
