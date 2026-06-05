# erc20-roles

> Role-based access control for an ERC-20 — `DEFAULT_ADMIN_ROLE` / `MINTER_ROLE` / `PAUSER_ROLE` with `AccessControlEnumerable`.

## Goals

- Replace the single-owner (`Ownable`) privilege model with role separation, the pattern most production tokens actually ship.
- Understand what `AccessControlEnumerable` adds on top of `AccessControl`: an `EnumerableSet.AddressSet` per role, so role membership can be listed on-chain.
- Exercise the full role lifecycle: constructor bootstrap, `grantRole`, `revokeRole`, `renounceRole`, and enumeration.

## Key points

- **Roles are `bytes32` constants**: `keccak256("MINTER_ROLE")` etc. `DEFAULT_ADMIN_ROLE` is `0x00` and, by default, is the admin of every other role — whoever holds it controls grant/revoke.
- **`onlyRole` modifier**: unauthorized callers revert with `AccessControlUnauthorizedAccount(account, role)` — assert it in tests with the custom-error selector, not a string.
- **Enumerable vs plain AccessControl**: plain `AccessControl` only answers `hasRole(role, account)` — you must already know the address. `AccessControlEnumerable` maintains an `EnumerableSet` per role, exposing `getRoleMemberCount` / `getRoleMember` / `getRoleMembers`, so dashboards and audits can list every minter without replaying events. The trade-off is extra gas on every grant/revoke for the set bookkeeping.
- **Why role separation matters**: the mint key (a bridge, a vesting contract) and the pause key (an incident-response bot) have different blast radii. Compromise of the pauser must not allow minting. The admin is typically a multisig that holds no operational role day-to-day.
- **`_update` multi-override**: ERC20 and ERC20Pausable both define `_update`; the explicit `override(ERC20, ERC20Pausable)` keeps the super chain intact.

## Files

| File | Topic |
|---|---|
| `src/RoleBasedERC20.sol` | ERC20 + ERC20Pausable + AccessControlEnumerable; MINTER/PAUSER gates |
| `test/RoleBasedERC20.t.sol` | Role-gated mint/pause, unauthorized reverts, grant/revoke/renounce, member enumeration |

## Run

```bash
forge build
forge test -vv
```
