# Q-11. Access control — promote yourself to admin

> **Difficulty**: Beginner ⭐⭐
> **Korean brief**: [`docs/challenges/q-11-access-control.md`](../../solidity-tutorial-lecture/docs/challenges/q-11-access-control.md)
> **Lecture (Korean)**: [PPT 4-1 §7](../../solidity-tutorial-lecture/docs/04-security-audit/4-1-vulnerabilities.md)

A single `VulnerableRegistry` is deployed and shared. The contract's
`grantAdmin(address)` setter forgot the `onlyOwner` modifier — anyone can
promote any address. You promote yourself, then finalise your solve.

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

## UI call sequence

1. `registry.grantAdmin(you)` — passes (no auth check).
2. `registry.claimAdmin()` — flips `solved[you] = true`.
3. `registry.isSolved(you)` → `true`.

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
