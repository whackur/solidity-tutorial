# Q-03. EthMailbox — receive / fallback / payable routing

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-03-eth-mailbox.md`](../../solidity-tutorial-lecture/docs/challenges/q-03-eth-mailbox.md)
> **Lecture (Korean)**: [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md), [PPT 2-3](../../solidity-tutorial-lecture/docs/02-dev-environment/2-3-entry-points-eth-calls.md)

A single shared `EthMailbox` is deployed once. Every user must trigger
each of its three ETH/calldata entry points from their own address.

## Goal

Make `EthMailbox.isSolved(yourAddress)` return `true` by hitting all
three routes for *your* address:

| Hit | What to send |
|---|---|
| `receive()` | a tx to the mailbox with `value > 0` and **empty calldata** |
| `fallback()` | a tx with `value` and **calldata starting with an unknown selector** (e.g. `setFallbackTag(bytes32)`) |
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

## UI call sequence

1. Send a plain transfer (e.g. wagmi `sendTransaction({ to: mailbox, value: 1 ether })`
   or `cast send <mailbox> --value 1ether`). Empty calldata → triggers `receive`.
2. Send a tx with the unknown selector `setFallbackTag(bytes32)` carrying any
   `bytes32` tag — falls through to `fallback`. With viem:
   `walletClient.sendTransaction({ to: mailbox, data: encodeFunctionData({ abi, functionName: 'setFallbackTag', args: [tag] }), value: 1 ether })`.
3. Call `receivePayable(<tag>)` with any value.
4. Read `isSolved(you)` → `true`.

## Concepts exercised

- The three Solidity entry-point types and how the EVM picks one:
  - empty calldata + value → `receive()`
  - selector matches a function → that function (named here)
  - any other calldata → `fallback()`
- `msg.sig` inside `fallback()` lets the contract sniff the would-be
  selector and special-case it (`setFallbackTag`, `countFallback`).
- `payable` on the named function is what lets it accept value.
