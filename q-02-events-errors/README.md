# Q-02. Selectors & try/catch — telling four revert kinds apart

> **Difficulty**: Entry ⭐
> **Korean brief**: [`docs/challenges/q-02-events-errors.md`](../../solidity-tutorial-lecture/docs/challenges/q-02-events-errors.md)
> **Lecture (Korean)**: [PPT 1-3](../../solidity-tutorial-lecture/docs/01-ethereum-evm/1-3-tx-success-failure.md), [PPT 2-2](../../solidity-tutorial-lecture/docs/02-dev-environment/2-2-basic-contract.md)
> **Reference source**: [`../counter/src/EventsAndErrors.sol`](../counter/src/EventsAndErrors.sol)

## Scenario

A revert in Solidity ships with one of four shapes — distinguished by the 4-byte selector at the front of the revert data:

| Kind | Trigger | Selector |
|---|---|---|
| `Error(string)` | `require(_, "msg")` / `revert("msg")` | `0x08c379a0` |
| `Panic(uint256)` | `assert(false)` / overflow / div-by-zero | `0x4e487b71` |
| custom error | `revert MyErr(arg)` | `keccak256("MyErr(...)")[:4]` |
| other | low-level revert | any |

## What to implement

```solidity
function knownSelectors() external pure
    returns (bytes4 errorStringSel, bytes4 panicSel, bytes4 customSel);

function classify(EventsAndErrors e, uint8 kind) external returns (uint8 label);
```

1. `knownSelectors` — compute the three selectors using `keccak256(signature)[:4]`. No hardcoded literals.
2. `classify(e, kind)` — call the matching error function and return:
   - `0` for caught `Error(string)`
   - `1` for caught `Panic(uint256)`
   - `2` for the `InsufficientBalance` custom error selector
   - `3` otherwise

Inputs:
- `kind == 0` → call `e.failWithRequire(0)`
- `kind == 1` → call `e.failWithAssert(false)`
- `kind == 2` → call `e.failWithCustomError(0, 1)`

## Hints

- `try ... catch Error(string memory)` and `catch Panic(uint256)` are dedicated branches.
- `catch (bytes memory reason)` exposes raw revert data; `bytes4(reason)` grabs the leading selector.

## Grading

```bash
forge test -vv
```
