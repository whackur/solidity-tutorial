# thirty-one-game — shared-state transaction warm-up

A small on-chain 31 game for observing wallet signatures, transaction ordering, state changes, events, and reverts. It is a classroom game, not a security-token or investment model.

## Rules

- Submit `1`, `2`, or `3` to advance the round index.
- Stake between 10 and 50 tokens with each submission.
- The address that reaches or passes 31 wins the configured share of the pool.
- The same address cannot submit twice in a row. Another address must submit before it may play again.

The final rule prevents one wallet from advancing a round alone. It does not enforce a fixed two-player turn order: `A -> B -> C` is valid because each submission has a different sender from the previous one.

## Classroom evidence

Compare `getRoundInfo(round)` and `lastSubmitter(round)` before and after a successful call. Then send a consecutive call from the same address and verify that the transaction reverts without changing either value.

Keep groups on separate deployments or coordinated rounds. `currentRound` is shared state, so an entire class using one game at once will interfere with each other.

## Run

```bash
cd thirty-one-game
forge build
forge test -vv
```

`script/Deploy.s.sol` reuses `SHARED_ERC20` when supplied and otherwise deploys a local mock token. `THIRTYONE_WINNER_PERCENTAGE` defaults to 80.

The game contains no address policy. In the STO profile, `SHARED_ERC20` is `BlocklistRestrictedToken`, so the token contract — not the game — rejects transfers involving an explicitly blocked sender or recipient.
