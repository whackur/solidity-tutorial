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
├── q-01-counter/ ... q-26-meta-tx/ — CTF-style challenge set (see q-INDEX.md)
├── common/               — Shared challenge base (SolvableBase / ISolvable), via @common remapping
├── dependencies/         — Soldeer-managed dependencies (do not edit manually)
├── config/foundry/       — Centralized package config (packages.json)
├── docker/               — anvil + pre-deployed snapshot image (Dockerfile, entrypoint, build-snapshot)
├── web/                  — Static faucet UI served by the faucet container
└── scripts/              — Shared helpers (generate-foundry-config, check-foundry-config, forge-fmt, collect-abi)
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
- Each package defines its own `remappings` in its `foundry.toml`. Do not add per-package or root `remappings.txt`; `forge` and editor tooling should resolve imports from `foundry.toml`.
- Tutorials are independent: copy patterns rather than abstract them. The one sanctioned shared module is `common/` (`SolvableBase` / `ISolvable`), referenced via the `@common` remapping; do not introduce other shared root-level Solidity code.
- **English only** in this repo. Every README, source-file comment, identifier, test message, and `q-*/README.md` is English.
- User-facing replies in chat may be in Korean — but committed files must remain English.
- This repository is independent. Do not link to or mention any external content repository from files in this repository. External materials may link here, but links must not point back the other way.
- Public files must not include full challenge walkthroughs, ordered transaction sequences, or direct answer playbooks. Hints, contract surfaces, goals, and conceptual explanations are allowed.
- Do not add `reference/PLAYBOOK.md`, `src/Solution.sol`, or `reference/Solution.ref.sol`. The full answer flow belongs outside this repository.
- Errors: prefer custom errors for production, but tutorials may keep `require` strings for clarity — match the tutorial's existing style.
- Markdown prose should not be hard-wrapped to a short column width. Keep one semantic paragraph or list item on one line; use line breaks only where the structure requires them, such as tables, lists, and code blocks.

## Challenge set (`q-*`) — multi-tenant web UI design

The `q-01-counter/` ... `q-26-meta-tx/` directories host CTF-style challenges designed for a **shared, multi-tenant deployment**. A single contract or Lab instance is deployed once; many users interact with it through an external web UI (or any wallet), distinguished only by `msg.sender`.

Students do **not** write Solidity to solve. They send transactions / read state through the UI.

### Hard rules

- **Per-user state**: all progress is keyed by `msg.sender` in mappings. Never use a global flag/counter that one user could trip for another.
- **`isSolved(address user) view returns (bool)`**: every challenge's main contract exposes this canonical check by inheriting `common/SolvableBase` (which layers `solve()` / `solvedBy(address)` / `Solved` on top). The UI polls `isSolved` to grade.
- **No answer files**: challenges are solved by transactions, but this repository must not publish ordered solve walkthroughs. Do not add `src/Solution.sol`, `reference/PLAYBOOK.md`, or `reference/Solution.ref.sol`.
- **Public tests are smoke/interface tests**: `test/Challenge.t.sol` must not publish the end-to-end solve path. Prefer constructor checks, initial `isSolved == false`, duplicate-instance rejection, per-user isolation checks that stop before solving, and negative/revert cases.
- **Factory pattern for per-user instances** (q-04, q-09, q-10, q-12, q-14, q-15, q-16, q-17, q-18, q-19, q-22, q-25): a single Lab contract exposes `createInstance(...)` which deploys the user's personal vulnerable / attacker / proxy contracts. The Lab tracks `mapping(address user => Instance)`.
- All Setup contracts must be re-entrancy-safe across users — one user's transaction must never read or write another user's slot.

### Layout

```
q-XX-{slug}/
├── README.md            ← English brief: scenario + hints (no ordered solve sequence)
├── foundry.toml
├── package.json
├── src/
│   └── Setup.sol        ← challenge environment + isSolved(address), extends common/SolvableBase
├── test/
│   └── Challenge.t.sol  ← public smoke/interface tests, no ordered solve flow
```

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

## Live deployment

The docker stack (`docker compose up`) is a local anvil snapshot. To publish to a real network, two paths write the same `deployments/<network>.json` plus a faucet-UI mirror at `docker/shared/<network>.json`:

- **Per-package** — `scripts/deploy.sh <network> <package|all>` (e.g. `pnpm deploy:hoodi all`). Runs each package's `script/Deploy.s.sol` as its own broadcast. Honors `VERIFY=1`, `SKIP_DEPLOYED=1` (resume — skip packages already in the record and reuse the recorded `sharedToken`), and `SKIP_PACKAGES="..."` (skip named packages).
- **Combined, one broadcast** — `scripts/deploy-all.sh <network>` (`pnpm deploy:hoodi:fast`). Runs the root `script/DeployAll.s.sol` under `[profile.deployall]` (adds `via_ir`, needed by `smart-account`), deploying every package inside a single `vm.startBroadcast()` so forge waits for confirmations once instead of ~45 times. It hand-mirrors each package's `Deploy.s.sol` — keep it in sync when a package's deploy logic changes.

Conventions shared by both: sign with `DEPLOYER_MNEMONIC` account 0 (gas payer); the classroom faucet is account 9; `default-erc-20` deploys first and its address is reused via the `SHARED_ERC20` env var by token-agnostic packages.

Funding: a full `all` run needs **~1.5 ETH** on the deployer — most is lab seeding (`q-16-oracle-spot` injects 1 ETH on its own; `q-09 / q-17 / q-18 / q-19` add `0.1 / 0.05 / 0.1 / 0.1`). The combined fast path needs the whole amount up front (single batch); the per-package path can be resumed with `SKIP_DEPLOYED=1` if it runs out mid-way.

`.env` gotchas: `DEPLOYER_MNEMONIC` must be **quoted** (`"word1 word2 ..."`) — an unquoted multi-word value silently breaks `source .env` and the deploy aborts. `scripts/deploy.sh` requires `jq` on `PATH`.

## Footguns

- Each subtree carries its own generated `foundry.toml`. Do not hand-edit; modify `config/foundry/packages.json` and regenerate.
- `dependencies/` is gitignored. Run `forge soldeer install` after a fresh clone.
- Hardhat/Ignition are no longer used. Any leftover `contracts/`, `ignition/`, `types/`, `artifacts/` directories should be removed.
