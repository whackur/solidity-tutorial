# Q-19. Reentrancy Basic — drain your personal vault with two calls

> **Difficulty**: Beginner ⭐
> **Companion to**: [`q-09-reentrancy/`](../q-09-reentrancy/README.md). This is a stripped-down version of the same pattern, designed as the first contact with re-entrancy in a beginner walkthrough.

A single `ReentrancyBasicLab` is deployed and pre-funded with ETH. Every user gets a fresh `(VulnerableMiniVault, BasicAttacker)` pair belonging only to that user. The vault violates CEI by sending ETH before updating accounting, which creates a re-entrancy window.

Unlike q-09, the lab pre-funds the attacker with bait so the student does not have to attach any ETH to their call. The total student transaction count is **two**.

## Goal

Make `ReentrancyBasicLab.isSolved(yourAddress)` return `true` by exploiting only *your* instance pair.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address attacker);
function vaultOf(address user) external view returns (VulnerableMiniVault);
function attackerOf(address user) external view returns (BasicAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 5 ether;
uint256 public constant BAIT = 0.05 ether;

// VulnerableMiniVault (your personal instance — DO NOT FIX)
function deposit() external payable;
function withdraw() external;       // CEI violation: external call before state update
function balances(address) external view returns (uint256);

// BasicAttacker (your personal instance, owner = you)
function attack() external;         // only owner; non-payable, uses pre-funded bait
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

## Student call sequence

1. `lab.createInstance()` — deploys vault + attacker for you, seeds the vault with 5 ETH, funds the attacker with 0.05 ETH of bait.
2. `attackerOf(you).attack()` — non-payable. Attacker uses its own bait to deposit then withdraw, and the vault's external call lands in the attacker's `receive()`, which re-enters `withdraw()` until the vault is empty.
3. `lab.isSolved(you)` returns `true`.

Optional: `attacker.drain()` to forward the stolen ETH to your EOA.

## What you can interact with

- A personal vault and a personal attacker contract.
- The attacker has an owner-only entry point that starts the exploit.
- Neither contract requires any value to be attached to your transactions.

## Hints

- Think about what the vault believes before and after it sends ETH out.
- The re-entry happens while the vault still has not finished updating its accounting.
- Calling `vault.withdraw()` directly from your EOA will revert immediately because `balances[you]` is zero — you must go through the attacker.

## Constraints

- Use only your own instance pair.
- The objective is to drain the vault, not to share state across users.

## Concepts exercised

- **CEI pattern (Checks-Effects-Interactions)**: state writes must happen *before* external calls so re-entering callers see post-effect state.
- **`call` invoking `receive()`** as the re-entry surface.
- **Why a beginner reentrancy demo is shorter than the production-style q-09**: removing the bait deposit step and the `payable` attack call keeps the student-side surface to two transactions, so the attention stays on the *re-entry mechanic itself* rather than the wiring.

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
