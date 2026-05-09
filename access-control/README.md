# access-control

> Companion sample for the *Access* portion of lecture chapter *3-5 (OpenZeppelin Access · Security · Utils)*.

## Goals

- Compare the privilege models of `Ownable` (single owner) and `AccessControl` (role-based) over the same domain (Vault).
- See why splitting responsibilities (mint vs pause) into separate roles makes operations safer — leaking one key only exposes a slice of the system.
- Understand the responsibility of `DEFAULT_ADMIN_ROLE`: only `grantRole` / `revokeRole`, *not* mint or pause.

## Key points

- `Ownable` keeps a single `owner` variable; if the key leaks, every owner-only function is exposed.
- `AccessControl` is `bytes32 role => mapping(account => bool)` — keys can be split per role.
- A leaked `MINTER_ROLE` key cannot pause; a leaked `PAUSER_ROLE` key cannot mint — the blast radius shrinks.
- In this example, `DEFAULT_ADMIN_ROLE` itself can only grant/revoke roles. Domain functions (mint/pause) are *not* directly callable by the admin.
- `AccessManager` (OZ 5.x) is the next evolution — roles are extracted into a dedicated contract for larger systems.

## Files

| File | Topic |
|---|---|
| `src/OwnableVault.sol` | Single-owner model — comparison baseline |
| `src/RoleManagedVault.sol` | MINTER_ROLE / PAUSER_ROLE / DEFAULT_ADMIN_ROLE split |
| `test/AccessControl.t.sol` | Role separation + grant/revoke + `AccessControlUnauthorizedAccount` revert on violation |
