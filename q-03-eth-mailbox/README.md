# Q-03. EthMailbox — receive / fallback / payable routing

> **Difficulty**: Beginner ⭐⭐

A single shared `EthMailbox` is deployed once. Every user must trigger
each of its three ETH/calldata entry points from their own address.

## Goal

Make `EthMailbox.isSolved(yourAddress)` return `true` by hitting all
three routes for *your* address:

| Hit | What to send |
|---|---|
| `receive()` | a tx to the mailbox with `value > 0` and **empty calldata** |
| `fallback()` | a tx with `value` and **calldata starting with an unknown selector** |
| `receivePayable(bytes32)` | a tx to the named function with `value > 0` |

## Contract surface

```solidity
receive() external payable;                                  // bumps hitReceive[me]
fallback() external payable;                                 // bumps hitFallback[me]; decodes tag if selector matches
function receivePayable(bytes32 tag) external payable;       // bumps hitReceivePayable[me]

function hitReceive(address user) external view returns (bool);
function hitFallback(address user) external view returns (bool);
function hitReceivePayable(address user) external view returns (bool);
function lastTrigger(address user) external view returns (uint8);
function lastTag(address user) external view returns (bytes32);
function lastValue(address user) external view returns (uint256);

function isSolved(address user) external view returns (bool);
```

## What you can interact with

- `receive()`, `fallback()`, and the named payable function.
- The contract records which route your own address has triggered.

## Hints

- Try to hit each entry point once with the right calldata shape.
- One route is for empty calldata, one is for unknown calldata, and one is the normal function call path.
- The tag value only needs to be consistent with your own exploration.

## Constraints

- Use your own address when checking progress.
- This is about routing, not about finding a secret value.

## Concepts exercised

- The three Solidity entry-point types and how the EVM picks one:
  - empty calldata + value → `receive()`
  - selector matches a function → that function (named here)
  - any other calldata → `fallback()`
- `msg.sig` inside `fallback()` lets the contract inspect the would-be selector and optionally special-case selected calldata shapes.
- `payable` on the named function is what lets it accept value.
