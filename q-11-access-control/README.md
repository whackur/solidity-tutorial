# Q-11. Access control — authorization boundary

> **Difficulty**: Beginner ⭐⭐

A single `Q11VulnerableRegistry` is deployed and shared. Inspect the state-changing functions and find the authorization boundary that matters for your own progress.

## Goal

Make `Q11VulnerableRegistry.isSolved(yourAddress)` return `true`.

## Contract surface

```solidity
function grantAdmin(address account) external;
function revokeAdmin(address account) external;    // owner-only (contrast)
function claimAdmin() external;                    // self-only, finalises solve
function adminPromoted(address) external view returns (bool);
function solved(address) external view returns (bool);
function isSolved(address user) external view returns (bool);
function owner() external view returns (address);
```

## What you can interact with

- A public admin-related mutator and a self-finalising function.

## Hints

- Compare which functions are guarded and which ones are not before deciding how to progress your own slot.
- The finalising step is intentionally tied to `msg.sender`.

## Constraints

- The exercise is about the missing guard, not about bypassing the finaliser.

> The two-step design keeps the tutorial multi-tenant safe: one caller
> must not be able to force-complete another user's slot.

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
