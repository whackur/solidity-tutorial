# Q-17. Reentrancy inflate — cross-function double-payout

> **Difficulty**: Intermediate ⭐⭐⭐
> **Korean brief**: [`docs/challenges/q-17-reentrancy-inflate.md`](../../solidity-tutorial-lecture/docs/challenges/q-17-reentrancy-inflate.md)
> **Lecture (Korean)**: [PPT 4-1 §2, 2-2](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

Variant of q-09. Same CEI violation in `withdraw`, but instead of
draining via recursive `withdraw` calls, you exploit a *cross-function*
mutator (`transferBalance`) to ship your still-valid balance to a
second account, which then withdraws a clean second time. Net effect:
a single deposit pays out twice — your balance is *inflated*, not just
recursively drained.

A pre-funded `InflateLab` is deployed. Each user calls `createInstance()`
to get a personal `(YieldVault, InflateAttacker, InflateHelper)` triple
with the vault pre-seeded with `1 ETH` (victim deposit).

## Goal

Make `InflateLab.isSolved(yourAddress)` return `true`. Three conditions:

- `address(vaultOf(you)).balance == 0` — vault drained.
- `address(attackerOf(you)).balance >= 1 ether` — first payout landed.
- `address(helperOf(you)).balance >= 1 ether` — second payout landed.

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

During `withdraw`'s external call to your attacker, the attacker's
`receive()` calls `transferBalance(helper, bal)`. The balance is
still `bal` (not yet zeroed!) so the transfer succeeds — and `helper`
gets credited the same `bal`. When the outer `withdraw` resumes and
zeroes `balances[attacker]`, the helper's slot is unaffected. Helper
then calls `withdraw()` cleanly and is paid a second time.

## UI call sequence

1. `lab.createInstance()` — deploys (vault, attacker, helper); vault is
   pre-funded with `1 ETH` of "victim deposit".
2. `attacker.attack{value: 1 ether}()` — outer attack:
   - Attacker deposits 1 ETH (vault: 2 ETH, balances[attacker] = 1).
   - Attacker calls `withdraw()`. Vault sends 1 ETH to attacker.
     During receive, attacker calls `transferBalance(helper, 1)` —
     balances[attacker] = 0, balances[helper] = 1.
   - Outer `withdraw` resumes and re-zeroes balances[attacker] (no-op).
3. `helper.pull()` — helper calls `withdraw()`. Vault sends 1 ETH to
   helper. Vault now: `0 ETH`.
4. `lab.isSolved(you)` → `true`. Optional: call `attacker.drain()` and
   `helper.drain()` to consolidate the 2 ETH back to your EOA.

## Concepts exercised

- **Cross-function reentrancy**: distinct from q-09's same-function
  recursion. Reentry from `withdraw` lands in *another* mutator
  (`transferBalance`) that reads the same state. A naive `nonReentrant`
  modifier applied only to `withdraw` does *not* block this — the
  attacker is calling a *different* function.
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
