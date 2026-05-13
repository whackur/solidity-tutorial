# Q-03. EthMailbox — receive / fallback / payable routing

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-03-eth-mailbox.md`](../../solidity-tutorial-lecture/docs/challenges/q-03-eth-mailbox.md)
> **Lecture (Korean)**: [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md), [PPT 2-3](../../solidity-tutorial-lecture/docs/02-dev-environment/2-3-entry-points-eth-calls.md)
> **Reference source**: [`../tx-basics/src/EthMailbox.sol`](../tx-basics/src/EthMailbox.sol)

## Scenario

`EthMailbox` records which entry path a value-bearing call took:

| Entry point | Trigger |
|---|---|
| `receive()` | value-bearing call with empty calldata |
| `fallback()` | calldata whose selector matches no named function |
| `receivePayable(bytes32)` | calldata whose selector matches `receivePayable(bytes32)` |

When the fallback receives the selector `bytes4(keccak256("setFallbackTag(bytes32)"))` plus an ABI-encoded `bytes32`, it decodes and stores `lastTag`.

## What to implement

```solidity
function triggerReceive(EthMailbox mb) external payable;            // -> Trigger.Receive
function triggerFallbackWithTag(EthMailbox mb, bytes32 tag) external payable; // -> Trigger.Fallback, lastTag == tag
function triggerReceivePayable(EthMailbox mb, bytes32 tag) external payable;  // -> Trigger.ReceivePayable, lastTag == tag
```

## Hints

- Empty calldata + value → `receive()`. Use `(bool ok,) = address(mb).call{value: msg.value}("");`.
- A made-up function selector → `fallback()`. Build calldata with `abi.encodeWithSignature("setFallbackTag(bytes32)", tag)`.
- The named call is just `mb.receivePayable{value: msg.value}(tag);`.

## Grading

```bash
forge test -vv
```

Each test verifies `mb.lastTrigger()`, `mb.lastTag()`, and `mb.lastValue()`.
