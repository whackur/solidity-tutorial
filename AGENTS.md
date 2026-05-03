# solidity-tutorial

Foundry-based monorepo of self-contained Solidity tutorials, managed with pnpm workspaces and Soldeer dependencies.

## Structure

```
├── default-erc-20/       — Basic ERC20 token
├── default-erc-721/      — Basic ERC721 NFT
├── eip-712-voucher/      — EIP-712 typed-data signed vouchers
├── eth-sign/             — eth_sign vs personal_sign signature recovery
├── minimal-proxy/        — EIP-1167 minimal proxy / Clones
├── simple-transparent/   — Transparent upgradeable proxy
├── simple-uups/          — UUPS upgradeable proxy
├── simple-wallet/        — Minimal ETH/ERC20 deposit wallet
├── thirty-one-game/      — Baskin-Robbins 31 game with stake-based prizes
├── dependencies/         — Soldeer-managed dependencies (do not edit manually)
├── config/foundry/       — Centralized package config (packages.json)
└── scripts/              — Shared Node.js helpers (generate-foundry-config, forge-fmt)
```

Each tutorial has its own `foundry.toml`, `src/`, `test/`, and `script/` directories and is independently buildable.

## Working Directory

**Always `cd` into a package directory before running Forge commands.**

Root-level `foundry.toml` holds shared settings (Soldeer deps, RPC endpoints, Etherscan keys, formatter config), but build/test/deploy must run from within the target package:

```bash
cd default-erc-20 && forge build
cd simple-uups && forge test -vvv
```

## Foundry config ownership

- Shared Foundry defaults are defined at the repository root.
- Package `foundry.toml` files are generated from `config/foundry/packages.json`.
- Regenerate and verify them with `pnpm generate:foundry-config` and `pnpm check:foundry-config`.
- Edit the shared source or package override data, then regenerate; do not hand-maintain package `foundry.toml` drift.

## Dependencies

- Managed by Soldeer (configured in root `foundry.toml` `[dependencies]` section).
- Resolved to `dependencies/` at the repo root; packages reference them via `../dependencies/` in their `libs` and `remappings`.
- Run `forge soldeer install` from the repo root to sync.

## Formatting

- The official Solidity formatting commands are `pnpm fmt` and `pnpm fmt:check` from the repository root.
- These root commands run `forge fmt --root .` against the explicit package targets defined in `scripts/forge-fmt.mjs`.
- Keep formatter rules centralized in the root `foundry.toml` `[fmt]` section.

## Key Conventions

- Solidity ^0.8.x, `solc = "0.8.34"`, `evm_version = "osaka"`.
- Each package defines its own `remappings` in its `foundry.toml` (no root `remappings.txt`).
- Tutorials are independent: do not introduce shared root-level Solidity code; copy patterns rather than abstract them.
- Comments and identifiers in English; user-facing replies may be in Korean.
- Errors: prefer custom errors for production, but tutorials may keep `require` strings for clarity — match the tutorial's existing style.

## Tests

- Forge: `*.t.sol` under each package's `test/`; use `Test` from `forge-std/Test.sol`.
- Prefer `assertEq`/`expectRevert` with custom-error selectors over string match where applicable.
- Cheatcodes: prefer `vm.prank`/`vm.startPrank`/`vm.sign`/`vm.signTypedData` over manual ECDSA in tests unless the tutorial is about signatures.

## Commands

- Install Soldeer deps: `forge soldeer install` (root).
- Install Node deps: `pnpm install` (root).
- Generate package configs: `pnpm generate:foundry-config`.
- Build all: `pnpm -r build`.
- Test all: `pnpm -r test`.
- Test one tutorial: `cd <tutorial> && forge test -vvv`.
- Format Solidity: `pnpm fmt`.

## Footguns

- Each subtree carries its own generated `foundry.toml`. Do not hand-edit; modify `config/foundry/packages.json` and regenerate.
- `dependencies/` is gitignored. Run `forge soldeer install` after a fresh clone.
- Hardhat/Ignition are no longer used. Any leftover `contracts/`, `ignition/`, `types/`, `artifacts/` directories should be removed.
