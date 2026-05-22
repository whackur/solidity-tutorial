# Q-02. Events & Errors — three flavours of revert

> **Difficulty**: Entry ⭐

`EventsAndErrors` exposes three intentionally-failing functions, each
reverting with a different ABI-encoded error kind. You observe each
revert via your wallet / web UI and submit its 4-byte selector back to
the contract.

## Goal

Make `EventsAndErrors.isSolved(yourAddress)` return `true` by submitting
all three selectors:

| Function called | Revert kind | What to note |
|---|---|---|
| `failWithRequire(0)` | `Error(string)` | the standard string-revert selector |
| `failWithAssert(false)` | `Panic(uint256)` | the panic selector |
| `failWithCustomError(...)` | custom `InsufficientBalance` | the custom error selector derived from its signature |

## Contract surface

```solidity
function failWithRequire(uint256 v) external pure;                   // reverts on v == 0
function failWithAssert(bool cond) external pure;                    // reverts on cond == false
function failWithCustomError(uint256 available, uint256 required)    // reverts on available < required
    external pure;

function reportErrorSelector(bytes4 selector) external;              // submit the string-revert selector
function reportPanicSelector(bytes4 selector) external;              // submit the panic selector
function reportCustomSelector(bytes4 selector) external;             // submit InsufficientBalance.selector

function isSolved(address user) external view returns (bool);
```

## What you can interact with

- Three intentionally failing functions and three selector-reporting functions.
- Each revert flavor is a different ABI encoding, so the revert payload itself is the clue.

## Hints

- Observe the first 4 bytes of each revert payload and map them back to the matching reporter.
- One error is the standard `require` string form, one is the `assert`/panic form, and one is a custom error.
- You can derive the custom selector from the error signature if you prefer not to inspect the revert data.

## Constraints

- You only need to prove you recognized each revert kind once.
- Keep the solution scoped to your own address.

## Concepts exercised

- The three revert encodings in EVM:
  - `Error(string)` — used by `require(cond, "msg")` and `revert("msg")`.
  - `Panic(uint256)` — used by `assert`, divide-by-zero, array-out-of-bounds, etc.
  - Custom errors — selector = `bytes4(keccak256("Name(types...)"))`.
- The 4-byte selector + ABI-encoded args layout is identical to a function
  call, which is what enables generic `try / catch (bytes memory)` decoding.
