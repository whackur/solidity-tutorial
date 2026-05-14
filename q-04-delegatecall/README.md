# Q-04. Delegatecall — `call` vs `delegatecall` storage

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-04-delegatecall.md`](../../solidity-tutorial-lecture/docs/challenges/q-04-delegatecall.md)
> **Lecture (Korean)**: [PPT 1-1](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-1-evm-internals.md), [PPT 2-3](../../solidity-tutorial-lecture/docs/02-dev-environment/2-3-entry-points-eth-calls.md)

A single `DelegatecallLab` is deployed. Each user gets a personal `(DelegateCaller, DelegateLogic)` pair and explores how two external-call types affect different storage contexts.

## Goal

Make `DelegatecallLab.isSolved(yourAddress)` return `true` by demonstrating that a normal call updates one contract's storage while a delegated call updates another contract's storage.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address caller, address logic);
function callerOf(address user) external view returns (DelegateCaller);
function logicOf(address user) external view returns (DelegateLogic);
function isSolved(address user) external view returns (bool);

// Caller (your personal instance)
function setVarsViaCall(DelegateLogic logic, uint256 newNumber) external payable;
function setVarsViaDelegatecall(address logic, uint256 newNumber) external payable;
function number() external view returns (uint256);
function sender() external view returns (address);

// Logic (your personal instance)
function setVars(uint256 newNumber) external payable;
function number() external view returns (uint256);
function sender() external view returns (address);
```

## What you can interact with

- `createInstance()` gives you a personal caller/logic pair.
- The two instance contracts expose the same state shape, but the call path determines which storage is updated.

## Hints

- Compare the result of a normal external call with the result of a delegated one.
- The key lesson is which contract owns the storage when the code runs.
- If the two addresses look similar, use that as a reminder that the code path matters more than the target address alone.

## Constraints

- Solve it with your own instance.
- Focus on the storage context, not on exact numbers.

## Concepts exercised

- `call`: target = the callee's address, storage = callee's, `msg.sender` = caller.
- `delegatecall`: target = caller's code seat, *storage = caller's*,
  `msg.sender` *preserved* from the outer call (your EOA).
- Storage-layout alignment is the foundation of proxy patterns (transparent /
  UUPS / Beacon — covered in upgradeable contract lectures).
- A storage-slot mismatch between caller and logic would silently corrupt
  the wrong slot — this is why proxies and implementations must mirror layouts.
