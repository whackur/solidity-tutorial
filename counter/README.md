# counter

> Entry-level contracts: minimum form of `contract` / `function` / `state variable`, then events and the four error variants on top of the same base.

## Goals

- Practice the minimum form of `contract` / `function` (visibility, mutability) / `state variable` / `constructor`.
- Compare event variants (0~3 indexed + anonymous) inside a single contract.
- Observe how the four error variants — `require(cond, "msg")` / `revert("msg")` / `revert CustomError(...)` / `assert` — surface as different selectors (`0x08c379a0` / `0x4e487b71` / custom 4-byte).

## Files

| File | Topic |
|---|---|
| `src/Counter.sol` | Minimum combination of state variable + indexed event + custom error. Pairs a SHARED `count` with a PERSONAL `counts[msg.sender]` so a class can compare both state models on one deployment |
| `src/SimpleStorage.sol` | Single storage slot + `ValueChanged(address indexed by, ...)` |
| `src/EventsAndErrors.sol` | Events with 0~3 indexed args + anonymous; require / revert / custom / assert / auto-Panic; selectors exposed directly |

## Key points

- `indexed` is meant for *off-chain filterable identifiers*. Values like `amount` typically stay non-indexed.
- `indexed string` / `indexed bytes` store only the *keccak256* of the original in topics — indexers cannot recover the source bytes.
- `anonymous` events skip topic[0] (the signature hash) so they cost less gas, but they break standard signature-based search and are not recommended for public contracts.
- `require("msg")` and `revert("msg")` produce the *same* `Error(string)` payload (selector `0x08c379a0`).
- `assert` / arithmetic overflow / div-by-zero / array out-of-bounds all surface as `Panic(uint256)` (selector `0x4e487b71`) with codes `0x01 / 0x11 / 0x12 / 0x32`.
- Custom errors carry a `keccak256("Name(type1,type2,...)")[:4]` selector plus ABI-encoded args — cheaper and easier to decode, which is why production contracts are migrating to them.

## Run

```bash
forge build
forge test -vv
forge test --gas-report
```
