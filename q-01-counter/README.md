# Q-01. Counter — your first transaction

> **Difficulty**: Entry ⭐
> **Korean brief**: [`docs/challenges/q-01-counter.md`](../../solidity-tutorial-lecture/docs/challenges/q-01-counter.md)
> **Lecture (Korean)**: [PPT 2-2](../../solidity-tutorial-lecture/docs/02-dev-environment/2-2-basic-contract.md), [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md)
> **Reference source**: [`../counter/src/Counter.sol`](../counter/src/Counter.sol)

## Scenario

A freshly deployed `Counter` starts at `count = 0`. Two tasks:

1. **Reach the target state** — drive `count` to *exactly `7`*. Any sequence of calls is fair game.
2. **Catch a custom error** — calling `decrement()` while `count == 0` reverts with `CounterUnderflow`. Catch the revert in `try / catch` and return its 4-byte selector.

## What to implement

Fill in `src/Solution.sol`:

```solidity
function solve(Counter c) external;          // after this, c.count() == 7
function catchUnderflow(Counter c)           // return the selector of c.decrement()'s revert
    external returns (bytes4);
```

## Hints

- `Counter.increment()` bumps `count` by 1.
- `Counter.decrement()` reverts with `CounterUnderflow` when count is zero.
- In `catch (bytes memory reason)`, the first 4 bytes of `reason` are the custom error selector. Pull them out with one line of inline assembly (`assembly { sel := mload(add(reason, 0x20)) }`) or `bytes4(reason)` cast.

## Grading

```bash
forge test -vv
```

- `test_Solve` — count equals 7
- `test_CatchUnderflow` — returned selector equals `Counter.CounterUnderflow.selector`
