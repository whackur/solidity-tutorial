# Q-17. Reentrancy inflate — cross-function double-payout

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-17-reentrancy-inflate.md`](../../solidity-tutorial-lecture/docs/challenges/q-17-reentrancy-inflate.md)
> **Lecture (Korean)**: [PPT 4-1 §2, 2-2](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

Variant of q-09. The same CEI violation appears in `withdraw`, but the interesting part is *cross-function* state reuse: another mutator touches the same balance map while the first function has not finished its effects.

A pre-funded `InflateLab` is deployed. Each user gets a personal `(YieldVault, InflateAttacker, InflateHelper)` triple.

## Goal

Make `InflateLab.isSolved(yourAddress)` return `true` by demonstrating the cross-function accounting failure in your own instance.

## Contract surface

```solidity
// Lab
function createInstance() external returns (address vault, address attacker, address helper);
function vaultOf(address user) external view returns (YieldVault);
function attackerOf(address user) external view returns (InflateAttacker);
function helperOf(address user) external view returns (InflateHelper);
function isSolved(address user) external view returns (bool);
uint256 public constant SEED = 1 ether;

// YieldVault (per user — DO NOT FIX)
function deposit() external payable;
function transferBalance(address to, uint256 amount) external;
function withdraw() external;
function balances(address) external view returns (uint256);

// InflateAttacker (per user, owner = you)
function attack() external payable;       // onlyOwner, bait > 0
function drain() external;                // onlyOwner

// InflateHelper (per user, owner = you)
function pull() external;                  // onlyOwner; calls vault.withdraw()
function drain() external;                 // onlyOwner
```

## The bug under attack

```solidity
function withdraw() external {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "no balance");
    (bool ok,) = msg.sender.call{value: bal}("");        // external call FIRST
    require(ok, "send failed");
    balances[msg.sender] = 0;                              // state update LAST
}

function transferBalance(address to, uint256 amount) external {
    require(balances[msg.sender] >= amount, "insufficient");
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

The key idea is that a reentrant callback does not have to call the same function again. It can enter a different mutator that still trusts shared state from the unfinished operation.

## What you can interact with

- A vault, an attacker, and a helper in your own instance.
- Two mutator paths touch the same balance map.

## Hints

- The reentry is cross-function, not just recursive.
- Watch what remains valid while the first external call is still in progress.
- If one function updates shared state too late, another function may observe or reuse stale assumptions.

## Constraints

- Use your own instance triple.
- The lesson is joint state safety across functions.

## Concepts exercised

- **Cross-function reentrancy**: distinct from q-09's same-function recursion. Reentry can land in another mutator that reads the same state. A naive `nonReentrant` modifier applied to only one entry point may not protect the whole invariant.
- **State invariants that cross functions**: any pair of functions that
  read/write the same balance map must be guarded *jointly*, not
  individually.
- **CEI restated**: state writes must happen *before* every external
  call, regardless of which other functions read that state.

## Defending it

Move the state write *before* the call (CEI):

```solidity
function withdraw() external {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "no balance");
    balances[msg.sender] = 0;                              // effects first
    (bool ok,) = msg.sender.call{value: bal}("");
    require(ok, "send failed");
}
```

Or use a global reentrancy guard (OZ `ReentrancyGuard` / `ReentrancyGuardTransient`)
that protects *every* mutator under one lock:

```solidity
function withdraw() external nonReentrant { ... }
function transferBalance(...) external nonReentrant { ... }
function deposit() external payable nonReentrant { ... }
```

Both fixes are required-but-distinct concepts; in production, do both.
