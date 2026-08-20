# thirty-one-game — shared-state transaction warm-up

A small on-chain 31 game for observing wallet signatures, transaction ordering, state changes, events, and reverts. It is a classroom game, not a security-token or investment model.

## Rules

- Submit `1`, `2`, or `3` to advance the round index.
- Stake between 10 and 50 tokens with each submission.
- The address that reaches or passes 31 wins the configured share of the pool.
- The same address cannot submit twice in a row. Another address must submit before it may play again.
- Only an address accepted by the configured allowlist may submit.

The final rule prevents one wallet from advancing a round alone. It does not enforce a fixed two-player turn order: `A -> B -> C` is valid because each submission has a different sender from the previous one.

## Classroom evidence

Compare `getRoundInfo(round)` and `lastSubmitter(round)` before and after a successful call. Then send a consecutive call from the same address and verify that the transaction reverts without changing either value.

Keep groups on separate deployments or coordinated rounds. `currentRound` is shared state, so an entire class using one game at once will interfere with each other.

The allowlist root must be configured and each player must call the allowlist's `register` function with a valid proof before joining a round. Revoking a registered address blocks its next submission without changing prior round state.

## Run

```bash
cd thirty-one-game
forge build
forge test -vv
```

`script/Deploy.s.sol` reuses `SHARED_ERC20` when supplied and otherwise deploys a local mock token. `THIRTYONE_ALLOWLIST` is required and must point to a contract exposing `isAllowed(address)`. `THIRTYONE_WINNER_PERCENTAGE` defaults to 80.
