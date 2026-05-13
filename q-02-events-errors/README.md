# Q-02. Events & Errors — three flavours of revert

> **Difficulty**: Entry ⭐
> **Korean brief**: [`docs/challenges/q-02-events-errors.md`](../../solidity-tutorial-lecture/docs/challenges/q-02-events-errors.md)
> **Lecture (Korean)**: [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md), [PPT 2-2](../../solidity-tutorial-lecture/docs/02-dev-environment/2-2-basic-contract.md)

`EventsAndErrors` exposes three intentionally-failing functions, each
reverting with a different ABI-encoded error kind. You observe each
revert via your wallet / web UI and submit its 4-byte selector back to
the contract.

## Goal

Make `EventsAndErrors.isSolved(yourAddress)` return `true` by submitting
all three selectors:

| Function called | Revert kind | Selector |
|---|---|---|
| `failWithRequire(0)` | `Error(string)` | `0x08c379a0` |
| `failWithAssert(false)` | `Panic(uint256)` | `0x4e487b71` |
| `failWithCustomError(1, 2)` | custom `InsufficientBalance` | `bytes4(keccak256("InsufficientBalance(uint256,uint256)"))` |

## Contract surface

```solidity
function failWithRequire(uint256 v) external pure;                   // reverts on v == 0
function failWithAssert(bool cond) external pure;                    // reverts on cond == false
function failWithCustomError(uint256 available, uint256 required)    // reverts on available < required
    external pure;

function reportErrorSelector(bytes4 selector) external;              // submit 0x08c379a0
function reportPanicSelector(bytes4 selector) external;              // submit 0x4e487b71
function reportCustomSelector(bytes4 selector) external;             // submit InsufficientBalance.selector

function isSolved(address user) external view returns (bool);
```

## UI call sequence

1. Send `failWithRequire(0)` — wallet shows an `Error(string)` revert.
   Copy the first 4 bytes of the revert data (`0x08c379a0`).
2. Call `reportErrorSelector(0x08c379a0)`.
3. Send `failWithAssert(false)` — wallet shows a `Panic(0x01)` revert.
4. Call `reportPanicSelector(0x4e487b71)`.
5. Send `failWithCustomError(1, 2)` — wallet shows the custom error data.
   Take the first 4 bytes.
6. Call `reportCustomSelector(<selector>)`.
7. Read `isSolved(you)` — `true`.

The custom error selector can also be precomputed with
`cast sig 'InsufficientBalance(uint256,uint256)'`.

## Concepts exercised

- The three revert encodings in EVM:
  - `Error(string)` — selector `0x08c379a0`, used by `require(cond, "msg")`
    and `revert("msg")`.
  - `Panic(uint256)` — selector `0x4e487b71`, used by `assert`,
    divide-by-zero, array-out-of-bounds, etc.
  - Custom errors — selector = `bytes4(keccak256("Name(types...)"))`.
- The 4-byte selector + ABI-encoded args layout is identical to a function
  call, which is what enables generic `try / catch (bytes memory)` decoding.
