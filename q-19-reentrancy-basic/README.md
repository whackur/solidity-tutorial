# Q-19. Reentrancy Basic — personal vault window

> **Difficulty**: Beginner ⭐
> **Companion to**: [`q-09-reentrancy/`](../q-09-reentrancy/README.md). This is a stripped-down version of the same pattern, designed as the first contact with re-entrancy.

A single `Q19ReentrancyBasicLab` is deployed and pre-funded with ETH. Every user gets a fresh `(Q19VulnerableMiniVault, Q19BasicAttacker)` pair belonging only to that user. The vault violates CEI by sending ETH before updating accounting, which creates a re-entrancy window.

Unlike q-09, the lab pre-funds the helper contract with bait so the student does not have to attach ETH while studying the re-entry window.

## Goal

Make `Q19ReentrancyBasicLab.isSolved(yourAddress)` return `true` by exploiting only *your* instance pair.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address attacker);
function vaultOf(address user) external view returns (Q19VulnerableMiniVault);
function attackerOf(address user) external view returns (Q19BasicAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 0.005 ether;
uint256 public constant BAIT = 0.00005 ether;

// Q19VulnerableMiniVault (your personal instance — DO NOT FIX)
function deposit() external payable;
function withdraw() external;       // CEI violation: external call before state update
function balances(address) external view returns (uint256);

// Q19BasicAttacker (your personal instance, owner = you)
function attack() external;         // only owner; non-payable
function drain() external;          // only owner; forward ETH back to your EOA
function attackAmount() external view returns (uint256);
function owner() external view returns (address);
```

## The bug under attack

```solidity
function withdraw() external {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "no balance");
    (bool ok,) = msg.sender.call{value: bal}("");  // ← external call FIRST
    require(ok, "transfer failed");
    balances[msg.sender] = 0;                       // ← state update LAST
}
```

The important observation is that the external call gives the receiver control before the vault finishes its bookkeeping.

## Hints

- Public challenge documents intentionally do not include the full transaction sequence.
- Inspect the contract surface and the goal condition, then derive the calls needed to make `isSolved(yourAddress)` return `true`.
- Use events, public getters, revert reasons, off-chain signatures, or RPC reads where the challenge topic suggests them.
- The exact walkthrough is not stored in this repository.

## What you can interact with

- A personal vault and a personal attacker contract.
- The attacker has an owner-only entry point that starts the exploit.
- The lab provides the initial exercise funding.

## Hints

- Think about what the vault believes before and after it sends ETH out.
- The re-entry happens while the vault still has not finished updating its accounting.
- Pay attention to whose balance the vault checks at the moment `withdraw()` starts.

## Constraints

- Use only your own instance pair.
- Keep all effects inside your own vault/attacker pair; other users' instances must remain untouched.

## Concepts exercised

- **CEI pattern (Checks-Effects-Interactions)**: state writes must happen *before* external calls so re-entering callers see post-effect state.
- **`call` invoking `receive()`** as the re-entry surface.
- **Why a beginner reentrancy demo is shorter than the production-style q-09**: removing the bait deposit step and the `payable` attack call keeps attention on the *re-entry mechanic itself* rather than the wiring.

## Defending it

```solidity
function withdraw() external nonReentrant {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "no balance");
    balances[msg.sender] = 0;                       // effects first
    (bool ok,) = msg.sender.call{value: bal}("");
    require(ok, "transfer failed");
}
```

See `q-09-reentrancy/` for the full discussion of fixes (CEI ordering, `ReentrancyGuard`, transient storage variants, and why `transfer` / `send` are not the answer).
