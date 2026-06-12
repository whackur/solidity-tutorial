# Q-09. Reentrancy — personal vault window

> **Difficulty**: Intermediate ⭐⭐⭐

A single `Q09ReentrancyLab` is deployed and pre-funded with ETH. Every user gets a fresh `(Q09VulnerableVault, Q09ReentrancyAttacker)` pair belonging only to that user. The vault violates CEI by sending ETH before updating accounting, which creates a reentrancy window.

## Goal

Make `Q09ReentrancyLab.isSolved(yourAddress)` return `true` by exploiting only *your* instance pair.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address attacker);
function vaultOf(address user) external view returns (Q09VulnerableVault);
function attackerOf(address user) external view returns (Q09ReentrancyAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 0.01 ether;

// Q09VulnerableVault (your personal instance — DO NOT FIX)
function deposit() external payable;
function withdraw() external;       // CEI violation: external call before state update
function balances(address) external view returns (uint256);

// Q09ReentrancyAttacker (your personal instance, owner = you)
function attack() external payable;  // only owner; bait > 0
function drain() external;           // only owner; forward ETH back to your EOA
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

## What you can interact with

- A personal vault and a personal attacker contract.
- The attacker has an owner-only entry point that starts the exploit.

## Hints

- Think about what the vault believes before and after it sends ETH out.
- The re-entry happens while the vault still has not finished updating its accounting.
- Think about how a contract receiver can use that unfinished accounting window.

## Constraints

- Use only your own instance pair.
- Keep all effects inside your own vault/attacker pair; other users' instances must remain untouched.

## Concepts exercised

- **CEI pattern (Checks-Effects-Interactions)**: state writes must happen
  *before* external calls so re-entering callers see post-effect state.
- **`call` invoking `receive()`** as the re-entry surface.
- **Why `transfer` / `send` aren't a fix**: they fail on contracts with
  >2300 gas requirements but break legitimate ERC-4337 / multisig
  receivers. The right fix is CEI ordering or `nonReentrant` guards.
- **Factory-of-vulnerabilities pattern**: pre-deployed per-user instances
  let many learners attack independently without exhausting a shared
  pool of bait ETH.

## Defending it

Patched `SafeVault` flips the order and/or adds `ReentrancyGuard`:

```solidity
function withdraw() external nonReentrant {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "no balance");
    balances[msg.sender] = 0;                       // effects first
    (bool ok,) = msg.sender.call{value: bal}("");
    require(ok, "transfer failed");
}
```
