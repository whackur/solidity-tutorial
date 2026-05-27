# Q-01. Q01Counter — your first transactions

> **Difficulty**: Entry ⭐

A single `Q01Counter` contract is deployed once; every user has their own
counter slot keyed by `msg.sender`. You solve the challenge by sending
transactions to it from your wallet / web UI.

## Goal

Make `Q01Counter.isSolved(yourAddress)` return `true`. That requires:

1. Your counter reaches the challenge target.
2. `sawUnderflow[you] == true` — you must trigger the `CounterUnderflow`
   revert, observe its selector, and submit that selector back via
   `reportUnderflowSelector(bytes4)`.

## Contract surface

```solidity
function increment() external;                          // counts[you] += 1
function decrement() external;                          // reverts CounterUnderflow at 0
function reset() external;                              // counts[you] = 0
function reportUnderflowSelector(bytes4 selector) external;
function counts(address user) external view returns (uint256);
function sawUnderflow(address user) external view returns (bool);
function isSolved(address user) external view returns (bool);
```

## What you can interact with

- `increment()`, `decrement()`, `reset()`, and `reportUnderflowSelector(bytes4)`.
- Your progress is tracked per address, so one wallet's actions do not affect another's slot.

## Hints

- The challenge is about reaching the target count and then proving you saw the custom error path.
- Trigger the underflow path once, then extract the selector from the revert data or derive it from the error name.
- Submit only the selector you learned; you do not need to guess any hidden value.

## Constraints

- Keep the focus on your own address.
- A revert is part of the intended exploration, not a failure of the exercise.

## Concepts exercised

- One external function call ⇔ one transaction.
- `msg.sender`-keyed mappings give every user their own state.
- Custom errors revert with the 4-byte function-selector encoding.
- A revert is the *EVM's contract-level error signal* — wallets can read
  the selector and bytes, web UIs surface it to the user.
