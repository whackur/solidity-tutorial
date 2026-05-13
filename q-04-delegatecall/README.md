# Q-04. call vs delegatecall — whose storage gets mutated?

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-04-delegatecall.md`](../../solidity-tutorial-lecture/docs/challenges/q-04-delegatecall.md)
> **Lecture (Korean)**: [PPT 1-1](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-1-evm-internals.md), [PPT 2-3](../../solidity-tutorial-lecture/docs/02-dev-environment/2-3-entry-points-eth-calls.md)
> **Reference source**: [`../tx-basics/src/DelegatecallDemo.sol`](../tx-basics/src/DelegatecallDemo.sol)

## Scenario

`DelegateCaller` and `DelegateLogic` share an identical storage layout.

- `setVarsViaCall(logic, num)` is a regular `call` — mutates `logic`'s storage.
- `setVarsViaDelegatecall(logic, num)` is a `delegatecall` — runs the same code but mutates the **caller's** storage. It also preserves the outer `msg.sender`.

## What to implement

```solidity
function runCall(DelegateCaller dc, DelegateLogic dl, uint256 num) external payable;
function runDelegatecall(DelegateCaller dc, address dl, uint256 num) external payable;
```

Forward `msg.value` through to the helpers.

## Hints

- `dc.setVarsViaCall{value: msg.value}(dl, num);`
- `dc.setVarsViaDelegatecall{value: msg.value}(dl, num);` — note this helper takes an `address`, not the typed interface.

## Grading

```bash
forge test -vv
```

- `test_CallChangesLogicNotCaller` — after `runCall`, only `dl.number()` changes.
- `test_DelegatecallChangesCallerNotLogic` — after `runDelegatecall`, only `dc.number()` changes.
- `test_SenderPreservedThroughDelegatecall` — `dc.sender() == address(solution)`.
