# Q-09. Reentrancy — drain your personal VulnerableVault

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-09-reentrancy.md`](../../solidity-tutorial-lecture/docs/challenges/q-09-reentrancy.md)
> **Lecture (Korean)**: [PPT 4-1](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A single `ReentrancyLab` is deployed and pre-funded with ETH. Every user
calls `createInstance()` once; the lab deploys a fresh `(VulnerableVault,
ReentrancyAttacker)` pair belonging to that user and seeds the vault
with `10 ETH` of victim funds. The user then sends `1 ETH` bait to their
attacker, which re-enters the vault's CEI-violating `withdraw()` and
walks away with `11 ETH`.

## Goal

Make `ReentrancyLab.isSolved(yourAddress)` return `true`. Two conditions
on *your* instance:

- `address(vaultOf(you)).balance == 0` — drained.
- `address(attackerOf(you)).balance >= 10 ETH` — bait + victim funds.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address attacker);
function vaultOf(address user) external view returns (VulnerableVault);
function attackerOf(address user) external view returns (ReentrancyAttacker);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 10 ether;

// VulnerableVault (your personal instance — DO NOT FIX)
function deposit() external payable;
function withdraw() external;       // CEI violation: external call before state update
function balances(address) external view returns (uint256);

// ReentrancyAttacker (your personal instance, owner = you)
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

When the vault calls `msg.sender.call{value: bal}("")`, your attacker's
`receive()` runs while `balances[attacker]` is still `bal`. The attacker
calls `vault.withdraw()` *again*, and again, until the vault's ETH
balance falls below `attackAmount`.

## UI call sequence

1. `lab.createInstance()` — deploys your vault + attacker; vault gets `10 ETH`.
2. `attackerOf(you).attack{value: 1 ether}()` — triggers the drain.
3. `lab.isSolved(you)` → `true`. Optional: `attacker.drain()` to move
   the stolen ETH back to your EOA.

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
