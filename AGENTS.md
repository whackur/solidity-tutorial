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
├── q-01-counter/ ... q-18-read-only-reentrancy/ — CTF-style challenge set (see q-INDEX.md)
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

- Solidity ^0.8.x, `solc = "0.8.35"`, `evm_version = "osaka"`.
- Each package defines its own `remappings` in its `foundry.toml`. A
  matching per-package `remappings.txt` is allowed (and used in `q-*`)
  purely so external Solidity language servers (Cursor / VS Code) can
  resolve imports — `forge` itself reads `foundry.toml`. Keep the two
  in sync; do not introduce a *root* `remappings.txt`.
- Tutorials are independent: do not introduce shared root-level Solidity code; copy patterns rather than abstract them.
- **English only** in this repo. Every README, source-file comment, identifier, test message, and `q-*/README.md` is English. Korean stays in `solidity-tutorial-lecture`.
- User-facing replies in chat may be in Korean — but committed files must remain English.
- Errors: prefer custom errors for production, but tutorials may keep `require` strings for clarity — match the tutorial's existing style.

## Challenge set (`q-*`) — multi-tenant web UI design

The `q-01-counter/` ... `q-10-signature-replay/` directories host CTF-style
challenges designed for a **shared, multi-tenant deployment**. A single
contract instance is deployed once; many users interact with it through
an external web UI (or any wallet), distinguished only by `msg.sender`.

Students do **not** write Solidity to solve. They send transactions /
read state through the UI.

### Hard rules

- **Per-user state**: all progress is keyed by `msg.sender` in mappings.
  Never use a global flag/counter that one user could trip for another.
- **`isSolved(address user) view returns (bool)`**: every challenge's
  main contract exposes this canonical check. The UI polls it to grade.
- **No `src/Solution.sol`**: challenges are solved by transactions, not
  by student-written contracts.
- **`vm.prank` multi-user tests**: `test/Challenge.t.sol` must simulate
  at least two distinct users solving in parallel and verify they do
  not interfere with each other's `isSolved` state.
- **Factory pattern for per-user instances** (q-04, q-09, q-10, q-12,
  q-14, q-15, q-16, q-17, q-18): a single Lab contract exposes
  `createInstance()` which deploys the user's personal vulnerable /
  attacker contracts. The Lab tracks `mapping(address user => Instance)`.
- **`reference/PLAYBOOK.md`**: instructor-only ordered call sequence
  (English). No `Solution.ref.sol` Solidity solution file.
- All Setup contracts must be re-entrancy-safe across users — one
  user's transaction must never read or write another user's slot.

### Layout

```
q-XX-{slug}/
├── README.md            ← English brief: scenario + UI call sequence
├── foundry.toml
├── package.json
├── src/
│   └── Setup.sol        ← challenge environment + isSolved(address)
├── test/
│   └── Challenge.t.sol  ← vm.prank multi-user grading
└── reference/
    └── PLAYBOOK.md      ← instructor-only ordered call list
```

The English `README.md` links to the matching Korean brief at
`solidity-tutorial-lecture/docs/challenges/q-XX-*.md`.

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
