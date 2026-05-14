# Q-11. Access control — promote yourself to admin

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-11-access-control.md`](../../solidity-tutorial-lecture/docs/challenges/q-11-access-control.md)
> **Lecture (Korean)**: [PPT 4-1 §7](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A single `VulnerableRegistry` is deployed and shared. One privileged-looking state-changing function is missing the guard that should restrict who can call it.

## Goal

Make `VulnerableRegistry.isSolved(yourAddress)` return `true`.

## Contract surface

```solidity
function grantAdmin(address account) external;     // BUG: no onlyOwner
function revokeAdmin(address account) external;    // owner-only (contrast)
function claimAdmin() external;                    // self-only, finalises solve
function adminPromoted(address) external view returns (bool);
function solved(address) external view returns (bool);
function isSolved(address user) external view returns (bool);
function owner() external view returns (address);
```

## The bug under attack

```solidity
// Intended to be onlyOwner. Missing modifier — anyone calls.
function grantAdmin(address account) external {
    adminPromoted[account] = true;
}
```

Compare with the correctly-guarded `revokeAdmin`:

```solidity
function revokeAdmin(address account) external {
    require(msg.sender == owner, "not owner");
    adminPromoted[account] = false;
}
```

## What you can interact with

- A public admin-related mutator and a self-finalising function.

## Hints

- One mutator is intentionally missing its privilege check.
- Compare which functions are guarded and which ones are not before deciding how to progress your own slot.

## Constraints

- The exercise is about the missing guard, not about bypassing the finaliser.

> The two-step (`grantAdmin` + `claimAdmin`) keeps the tutorial
> multi-tenant safe: a malicious caller can `grantAdmin(victim)` but
> only `victim` can finalise their slot — no force-solve from outside.

## Concepts exercised

- **Function-level access control** with `require(msg.sender == ...)`
  vs `onlyOwner` / `AccessControl` / OZ `Ownable`.
- **The "forgotten modifier" bug class** — invisible at runtime because
  the function name + signature looks normal, only the absence of a
  guard makes it dangerous. Linters / 4-byte audits / unit tests on
  the negative path catch it.
- **Why `view`/`getter` access matters less than mutator access** —
  state writes are the privileged surface.

## Defending it

```solidity
modifier onlyOwner() {
    require(msg.sender == owner, "not owner");
    _;
}

function grantAdmin(address account) external onlyOwner {
    adminPromoted[account] = true;
}
```

Production: OZ `Ownable`, `AccessControl`, or `AccessManager` for
role-graph admin.
