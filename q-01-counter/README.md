# Q-01. Counter — your first transactions

> **Difficulty**: Entry ⭐
> **Korean brief**: [`docs/challenges/q-01-counter.md`](../../solidity-tutorial-lecture/docs/challenges/q-01-counter.md)
> **Lecture (Korean)**: [PPT 2-2](../../solidity-tutorial-lecture/docs/02-dev-environment/2-2-basic-contract.md), [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md)

A single `Counter` contract is deployed once; every user has their own
counter slot keyed by `msg.sender`. You solve the challenge by sending
transactions to it from your wallet / web UI.

## Goal

Make `Counter.isSolved(yourAddress)` return `true`. That requires:

1. `counts[you] == 7`.
2. `sawUnderflow[you] == true` — you must trigger the `CounterUnderflow`
   revert (decrement at count 0), observe its 4-byte selector, and submit
   that selector back via `reportUnderflowSelector(bytes4)`.

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

## UI call sequence (one valid playbook)

1. Send 7 `increment()` transactions from your wallet.
   - Check: `counts(you) == 7`.
2. From a *fresh* address (or `reset()` your slot first), send `decrement()`.
   - It will revert. Copy the 4-byte selector from the revert data.
3. Switch back to your main wallet and call
   `reportUnderflowSelector(0xCAFE...)` with the selector you copied.
4. Read `isSolved(you)` — should be `true`.

> The selector for `error CounterUnderflow()` is `keccak256("CounterUnderflow()")[:4]`.
> Compute it yourself or grab it from the failing transaction's revert payload.

## Concepts exercised

- One external function call ⇔ one transaction.
- `msg.sender`-keyed mappings give every user their own state.
- Custom errors revert with the 4-byte function-selector encoding.
- A revert is the *EVM's contract-level error signal* — wallets can read
  the selector and bytes, web UIs surface it to the user.

## Notes for instructors

The playbook used by the test harness is documented in
[`reference/PLAYBOOK.md`](reference/PLAYBOOK.md). Auto-grading in
`test/Challenge.t.sol` simulates two users solving in parallel with
`vm.prank` to verify they do not interfere.
