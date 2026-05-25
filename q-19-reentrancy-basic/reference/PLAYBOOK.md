# Q-19 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `ReentrancyBasicLab` (pre-funded with at least `(SEED + BAIT) * N` ETH).
`USER` = user's EOA — does not need any ETH for this challenge.

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys `(vault, attacker)` for USER; lab calls `vault.deposit{value: 5e18}()` so `balances[lab] = 5e18`, then forwards `0.05e18` to `attacker` as bait |
| 2 | view | `LAB` | `attackerOf(USER)` | — | snapshot personal attacker address |
| 3 | `USER` | `attacker` | `attack()` | 0 | attacker uses its own 0.05 ETH bait, deposits then withdraws, and the vault's external call lands in `attacker.receive()`, which re-enters `withdraw()` repeatedly until `vault.balance < attackAmount` |
| 4 | view | `LAB` | `isSolved(USER)` | — | `true` (vault drained, attacker holds ≥ 5 ETH) |
| 5 | `USER` | `attacker` | `drain()` (optional) | — | forwards all stolen ETH to USER's EOA |

## Pre-deploy funding

```solidity
ReentrancyBasicLab lab = new ReentrancyBasicLab();
vm.deal(address(lab), 100 ether);   // tutorial setup; ~20 users at (SEED + BAIT) each
```

On testnet the deployer can fund the lab via a normal ETH transfer
(empty calldata) — the lab has `receive() external payable {}`.

## Mechanics of the drain (re-entrancy trace)

```
USER -> attacker.attack()                          // non-payable, attacker uses its own bait
  attacker -> vault.deposit{value: 0.05e18}()      // balances[attacker] = 0.05e18
  attacker -> vault.withdraw()
    vault: bal = balances[attacker] = 0.05e18
    vault.call{value: 0.05e18}(attacker)           // sends 0.05e18 to attacker
      attacker.receive() runs
      attacker -> vault.withdraw()                 // re-entry!
        vault: bal = balances[attacker] = 0.05e18 (still!)
        vault.call{value: 0.05e18}(attacker)
          attacker.receive() ... and so on, ~100 iterations until
          vault.balance < 0.05e18, then receive() stops re-entering
        balances[attacker] = 0
      balances[attacker] = 0 (already zero — harmless)
    balances[attacker] = 0 (already zero — harmless)
```

Each user's vault is independent — alice's attack does not touch bob's
vault, so two users can run the attack concurrently.

## Differences from Q-09

| | Q-19 (this) | Q-09 |
|---|---|---|
| Vault seed | 5 ETH | 10 ETH |
| Bait source | Lab pre-funds attacker with 0.05 ETH | Student attaches `value` to `attack()` |
| `attack()` signature | non-payable | `payable` |
| Student transactions | 2 (createInstance + attack) | 3 (createInstance + attack(payable) + optional drain) |
| Intended audience | Beginner — first contact with re-entrancy | Intermediate — covers bait, drain, defense comparison |

## Notes

- `attacker.attack()` is `onlyOwner` so a third party cannot trigger
  someone else's attacker. This prevents an outsider from "solving" a
  challenge for a user.
- `createInstance()` reverts with `"already created"` if USER already
  has a pair. Reset would require redeploying the lab.
- The receive() loop count (~100 iterations of 0.05 ETH against a 5 ETH
  seed) is high enough to be visible in a trace but low enough to avoid
  OOG on the default block gas limit.
