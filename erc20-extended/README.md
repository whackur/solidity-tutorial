# erc20-extended

> Companion sample for lecture chapter *3-2 (ERC-20 token issuance and extensions)* — combined extensions.

## Goals

- Combine the five ERC-20 extensions most commonly used in production into one contract and feel the multiple-inheritance traps first-hand.
- Understand why explicit multi-overrides on `_update` and `nonces` are required (compile error → fix).
- See what each extension solves: `ERC20Permit` (EIP-2612), `ERC20Votes` checkpoints, `ERC20Capped`, `ERC20Pausable`, `ERC20Burnable`.

## Key points

- **`_update` multi-override**: ERC20Capped / ERC20Pausable / ERC20Votes all override `_update`. Listing the three keeps the super chain intact.
- **`nonces` multi-override**: both ERC20Permit and Nonces define `nonces(address)` → `override(ERC20Permit, Nonces)` is mandatory.
- **Permit domain isolation**: `EIP712("ExtendedToken", "1")` + `chainId` + `verifyingContract` — signatures cannot replay across tokens or chains.
- **Votes checkpoints**: voting power activates only after `delegate(self)`. A flash-loan that *briefly* inflates the balance has no effect on the *past* block's voting power — defeats governance flash-loan attacks.
- **Capped vs unlimited mint**: with a cap, `_mint` reverts with `ERC20ExceededCap` when crossed.

## Files

| File | Topic |
|---|---|
| `src/ExtendedERC20.sol` | Five extensions + Ownable combined; `_update` / `nonces` multi-override demo |
| `test/ExtendedERC20.t.sol` | Capped / Burnable / Pausable / Votes(checkpoint) / Permit (signature-based approve) |

## Run

```bash
forge build
forge test -vv
```
