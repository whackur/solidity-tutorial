# Q-25. UUPS upgrade — V1 to V2

> **Difficulty**: Intermediate ⭐⭐

You get your own UUPS proxy pointing at `Q25CounterV1`. You are its owner. The exercise is about moving a proxy to a compatible implementation through the UUPS authorization gate.

## Goal

Make `Q25UupsLab.isSolved(you)` return `true`. The lab detects the upgrade by
calling `version()` on your proxy — a function that exists only on V2.

## Contract surface

```solidity
// Q25UupsLab
function createInstance() external returns (address proxy);   // your own proxy on V1
function proxyOf(address user) external view returns (address);
function v1Impl() external view returns (Q25CounterV1);
function v2Impl() external view returns (Q25CounterV2);
function isSolved(address user) external view returns (bool);
function solve() external;

// Your proxy (Q25CounterV1 / UUPSUpgradeable interface)
function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
function increment() external;
function count() external view returns (uint256);
function owner() external view returns (address);
```

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

- Only the owner can upgrade. `createInstance` makes you the owner of your
  proxy, so the upgrade authorizes.
- V2 inherits V1's storage layout (`count`, `owner`) — that is what makes the
  upgrade storage-compatible. Reordering or removing those would corrupt state.

## Concepts exercised

- UUPS (EIP-1822) — upgrade logic lives in the implementation, not the proxy.
- `_authorizeUpgrade` as the upgrade permission gate.
- EIP-1967 implementation slot (what `upgradeToAndCall` rewrites).
- Storage-layout compatibility across implementation versions.
