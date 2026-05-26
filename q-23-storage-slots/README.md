# Q-23. Storage slots — reading "private" state

> **Difficulty**: Intermediate ⭐⭐

A `Vault` contract holds two secret 32-byte values in storage. Neither has
a getter. Your job is to read both directly from the chain and submit them
back — proving you understand that `private` does **not** mean private.

## Goal

Call `Vault.submit(bytes32 a, bytes32 b)` with the values currently stored
in the two secret slots. On success, `isSolved(you)` flips to true and you
can call `solve()` to record the on-chain proof.

## Contract surface

```solidity
function submit(bytes32 a, bytes32 b) external;        // wins on correct values
function submitted(address) external view returns (bool);
function SLOT_B() external view returns (bytes32);     // public constant — slot of secretB
function isSolved(address user) external view returns (bool);
function solve() external;                             // record proof of solve
function solvedBy(address user) external view returns (bool);
```

There is **no getter** for `secretA`. It is declared `private`. You still
have to recover it from storage.

## What you need to know

Solidity assigns storage slots **in declaration order across the full
inheritance chain**:

1. The base contract (`SolvableBase`) declares `mapping(address => bool) solvedBy` first → slot **0**.
2. The derived `Vault` declares `bytes32 private secretA` next → slot **1**.
3. `bytes32 public constant SLOT_B` is `constant`, so it lives in code, not storage. It does **not** take a slot.
4. `mapping(address => bool) public submitted` is the next storage variable → slot **2**.

For mappings the slot number stores nothing useful itself; per-key values
live at `keccak256(abi.encode(key, slot))`. But that detail does not matter
here — you only need to read the two fixed slots.

`secretB` is stored at an **arbitrary** slot computed at compile time:

```solidity
bytes32 public constant SLOT_B = keccak256("q23.secret.b");
```

This is the same pattern EIP-1967 uses for proxy storage: pick a slot far
out of range of the sequential layout so it cannot collide with regular
variables.

## How to read storage off-chain

The JSON-RPC method is `eth_getStorageAt(address, slot, block)`. From the
Foundry toolbox:

```bash
# Read secretA (slot 1, sequential)
cast storage <vault> 1 --rpc-url http://localhost:8545

# Read secretB (arbitrary slot — fetch SLOT_B from the contract first)
SLOT_B=$(cast call <vault> "SLOT_B()" --rpc-url http://localhost:8545)
cast storage <vault> "$SLOT_B" --rpc-url http://localhost:8545
```

You can also dump the whole layout the compiler decided on:

```bash
forge inspect Vault storage-layout
```

## Hints

- `private` hides the **Solidity getter**, not the bytes. EVM storage has
  no access control.
- `constant` variables never consume a storage slot — they are inlined into
  bytecode at compile time.
- The "arbitrary slot" trick is everywhere in production: EIP-1967 proxies
  (`keccak256("eip1967.proxy.implementation") - 1`), ERC-7201 namespaced
  storage, Diamond Standard facet storage. Same idea.

## Constraints

- `submit` validates each slot independently and tells you which one was
  wrong via the revert reason (`WrongSecretA` / `WrongSecretB`).
- The secrets are seeded once at deploy time from `block.timestamp` +
  `blockhash`, so they change every time the docker stack is rebuilt.

## Concepts exercised

- Solidity storage layout — declaration order maps to slot index.
- `private` vs storage visibility — they are not the same thing.
- `constant` does not occupy a slot.
- Arbitrary storage slots via `assembly { sstore }` / `sload` and the
  EIP-1967 / ERC-7201 family of patterns that rely on it.
- `eth_getStorageAt` and `cast storage` for off-chain inspection.
