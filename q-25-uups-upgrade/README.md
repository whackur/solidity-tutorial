# Q-25. UUPS upgrade — V1 to V2

> **Difficulty**: Intermediate ⭐⭐

You get your own UUPS proxy pointing at `CounterV1`. You are its owner. Upgrade
it to `CounterV2` — only the owner can, because `_authorizeUpgrade` is gated by
`onlyOwner`. Once upgraded, the proxy gains `version()` and the challenge is solved.

## Goal

Make `UupsLab.isSolved(you)` return `true`. The lab detects the upgrade by
calling `version()` on your proxy — a function that exists only on V2.

## Contract surface

```solidity
// UupsLab
function createInstance() external returns (address proxy);   // your own proxy on V1
function proxyOf(address user) external view returns (address);
function v1Impl() external view returns (CounterV1);
function v2Impl() external view returns (CounterV2);
function isSolved(address user) external view returns (bool);
function solve() external;

// Your proxy (CounterV1 / UUPSUpgradeable interface)
function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
function increment() external;
function count() external view returns (uint256);
function owner() external view returns (address);
```

## Solve sequence

```bash
LAB=<lab address>

# 1. createInstance — your proxy starts on CounterV1, owner = you
cast send $LAB "createInstance()" --rpc-url http://localhost:8545 --private-key <yours>
PROXY=$(cast call $LAB "proxyOf(address)(address)" <you> --rpc-url http://localhost:8545)
V2=$(cast call $LAB "v2Impl()(address)" --rpc-url http://localhost:8545)

# 2. upgrade your proxy to V2 (onlyOwner — that's you)
cast send $PROXY "upgradeToAndCall(address,bytes)" $V2 0x --rpc-url http://localhost:8545 --private-key <yours>

# 3. solve
cast send $LAB "solve()" --rpc-url http://localhost:8545 --private-key <yours>
```

## Hints

- `upgradeToAndCall` with empty `data` (`0x`) just swaps the implementation,
  no extra call.
- Only the owner can upgrade. `createInstance` makes you the owner of your
  proxy, so the upgrade authorizes.
- V2 inherits V1's storage layout (`count`, `owner`) — that is what makes the
  upgrade storage-compatible. Reordering or removing those would corrupt state.

## Concepts exercised

- UUPS (EIP-1822) — upgrade logic lives in the implementation, not the proxy.
- `_authorizeUpgrade` as the upgrade permission gate.
- EIP-1967 implementation slot (what `upgradeToAndCall` rewrites).
- Storage-layout compatibility across implementation versions.
