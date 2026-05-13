# Q-04. Delegatecall — `call` vs `delegatecall` storage

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-04-delegatecall.md`](../../solidity-tutorial-lecture/docs/challenges/q-04-delegatecall.md)
> **Lecture (Korean)**: [PPT 1-1](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-1-evm-internals.md), [PPT 2-3](../../solidity-tutorial-lecture/docs/02-dev-environment/2-3-entry-points-eth-calls.md)

A single `DelegatecallLab` is deployed. Each user calls `createInstance()`
once to get a personal `(DelegateCaller, DelegateLogic)` pair, then drives
those two contracts from the wallet UI to set storage via two different
external-call types.

## Goal

Make `DelegatecallLab.isSolved(yourAddress)` return `true` by leaving your
personal instances in this exact state:

- `logicOf(you).number() == 42` — written by `call` (target's storage).
- `callerOf(you).number() == 99` — written by `delegatecall` (caller's storage
  via the logic contract's code).

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

## UI call sequence

1. From your wallet: `lab.createInstance()`. The receipt event gives you the
   two addresses; the lab also exposes `callerOf(you)` / `logicOf(you)`.
2. Call `caller.setVarsViaCall(logic, 42)` (value optional).
   - Observe: `logic.number() == 42`, `caller.number() == 0`. Normal `call`
     writes to the callee's storage.
3. Call `caller.setVarsViaDelegatecall(logic, 99)` (value optional).
   - Observe: `caller.number() == 99`, `logic.number()` still `42`.
     `delegatecall` executes logic's code *in caller's storage context*.
4. Read `lab.isSolved(you)` → `true`.

## Concepts exercised

- `call`: target = the callee's address, storage = callee's, `msg.sender` = caller.
- `delegatecall`: target = caller's code seat, *storage = caller's*,
  `msg.sender` *preserved* from the outer call (your EOA).
- Storage-layout alignment is the foundation of proxy patterns (transparent /
  UUPS / Beacon — covered in upgradeable contract lectures).
- A storage-slot mismatch between caller and logic would silently corrupt
  the wrong slot — this is why proxies and implementations must mirror layouts.
