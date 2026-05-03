# AGENTS.MD

Telegraph style. Root rules only. Read scoped `AGENTS.md` before subtree work.

## Start

- Repo: `https://github.com/whackur/solidity-tutorial`
- Replies: repo-root refs only: `eip-712-voucher/src/Voucher.sol:42`. No absolute paths, no `~/`.
- Purpose: Solidity learning examples. Each subtree is a self-contained tutorial; do not cross-pollinate examples without reason.
- High-confidence answers only when fixing/triaging: verify source, tests, and dependency contracts (OpenZeppelin, forge-std) before deciding.
- Dependency-backed behavior: read upstream OZ/forge-std source/types in `dependencies/` first. Do not assume APIs, defaults, errors, or runtime behavior.
- Missing deps: `forge soldeer install`, retry once, then report first actionable error.
- Language: replies in Korean; code comments and identifiers in English.
- New `AGENTS.md` in any subtree: add sibling `CLAUDE.md` symlink so OpenCode and Claude Code share context.

## Map

- Root: `foundry.toml`, `remappings.txt`, `package.json`, `pnpm-workspace.yaml` (each subdir is a workspace package).
- Tutorials (each one self-contained, own `foundry.toml` may exist):
  - `default-erc-20/` — basic ERC20.
  - `default-erc-721/` — basic ERC721.
  - `eip-712-voucher/` — EIP-712 typed-data vouchers.
  - `eth-sign/` — ECDSA signing examples.
  - `minimal-proxy/` — EIP-1167 minimal proxy.
  - `simple-uups/` — UUPS upgradeable proxy.
  - `simple-transparent/` — transparent upgradeable proxy.
  - `simple-wallet/` — minimal wallet.
  - `thirty-one-game/` — small game contract.
- Deps: `dependencies/` (Soldeer), `lib/` (forge submodules if any), `node_modules/` (pnpm).

## Architecture

- Each tutorial is independent. Do not introduce shared root-level Solidity code; copy patterns rather than abstract them.
- Imports use Soldeer remappings from root `remappings.txt` (`@openzeppelin-contracts/`, `@openzeppelin-contracts-upgradeable/`, `forge-std/`, `openzeppelin-foundry-upgrades/`).
- Upgradeable patterns (`simple-uups`, `simple-transparent`) use `openzeppelin-foundry-upgrades`; do not hand-roll proxy storage layouts unless the tutorial is about that.
- EIP-712 / signature flows: keep domain separator constants explicit; do not hide them in helper libs.
- Test contracts live next to source under each tutorial's `test/`.

## Commands

- Toolchain: Foundry (forge, cast, anvil) + pnpm 10 + Hardhat 3 (in some packages).
- Install Soldeer deps: `forge soldeer install` (generates `dependencies/` + remappings).
- Install Node deps: `pnpm install`.
- Build all: per-tutorial `forge build`; root `pnpm -r test` runs per-package `test` script.
- Test single tutorial: `cd <tutorial>; forge test -vvv`.
- Format Solidity: `pnpm fmt` (`forge fmt .`); JS/TS: `pnpm format` (`prettier --write .`).
- Lint: `pnpm lint` (eslint), Solhint via package-local config when present.
- Combined: `pnpm lint:all` = format + lint.
- Hardhat tutorials: run `pnpm hardhat test` / `pnpm hardhat ignition deploy` from inside that package.
- Anvil local node: `anvil` from any tutorial dir; deploy via `forge script` or `hardhat ignition`.

## Code

- Solidity ^0.8.x, license `MIT` or `UNLICENSED` per file.
- `forge fmt` rules (root `foundry.toml [fmt]`): line length 100, tab width 4, double quotes, `bracket_spacing = false`, `int_types = "long"`, `multiline_func_header = "attributes_first"`, `quote_style = "double"`, `number_underscore = "thousands"`.
- Naming: contracts `PascalCase`, functions/vars `camelCase`, constants `UPPER_SNAKE_CASE`, errors `PascalCase`.
- Errors: prefer custom errors over `require(..., string)` for gas; tutorials may keep `require` strings for clarity — match the tutorial's existing style.
- Storage: explicit `private`/`internal`/`public`; do not flip visibility unless the tutorial is about it.
- Upgradeable: use `__Init_unchained` patterns; never add state variables above the storage gap; verify with `openzeppelin-foundry-upgrades` validator.
- Comments: NatSpec on external/public; brief inline only for non-obvious logic. American English.

## Tests

- Forge: `*.t.sol` under `test/`; use `Test` from `forge-std/Test.sol`. Prefer `assertEq`/`expectRevert` with custom-error selectors over string match.
- Fuzz: tutorials may use bounded fuzz (`vm.assume`, `bound`); keep iterations reasonable.
- Fork tests: gate behind `vm.envOr` and an env flag; do not assume RPC env in CI.
- Hardhat: `test/*.ts` with mocha + viem/ethers; mirror Forge assertions where the tutorial demonstrates both.
- Cheatcodes: prefer `vm.prank`/`vm.startPrank` over signing ECDSA in tests unless the tutorial is about signatures.

## Git

- Branch: `main`. Direct commits OK for tutorial fixes; PR only when restructuring multiple tutorials.
- Commits: conventional-ish (`feat:`, `fix:`, `chore:`, `docs:`); one tutorial per commit when feasible.
- Do not commit `dependencies/`, `lib/`, `node_modules/`, `cache/`, `out/`, `artifacts/`, `broadcast/`, `*.lock` (already in `.gitignore`).
- Do not commit `.env` or any RPC keys / private keys.
- `AGENTS.md` and `CLAUDE.md` are tracked; per-subtree variants are also tracked so OpenCode/Claude Code agents share context.

## Security

- Tutorials may demonstrate insecure patterns; mark them clearly with NatSpec `@dev WARNING:` or a section in the tutorial's README.
- Never hardcode real private keys or mnemonics; use `vm.envUint("PRIVATE_KEY")` patterns and a sample `.env.example` if needed.
- `simple-wallet` and signature-based examples: redact any real signer addresses before committing.
- Soldeer deps pinned exact (`forge-std = "1.12.0"`, `@openzeppelin-contracts = "5.5.0"`); do not bump silently.

## Footguns

- `remappings.txt` is generated by Soldeer. If imports break, run `forge soldeer install` rather than hand-editing.
- Each subtree may carry its own `foundry.toml` overriding root; check before assuming root config applies.
- `pnpm-workspace.yaml` globs `*` — every top-level dir is a package, including non-tutorial ones. Be precise with `pnpm -F <pkg>`.
- Hardhat 3 is ESM-first; `hardhat.config.ts` uses `defineConfig` and TS imports must be `.js` extension at runtime.
- Windows: forge symlinks for proxy artifacts may not resolve; prefer relative imports in scripts.
- `forge fmt` rewrites quote style and bracket spacing; review diffs before committing format-only changes.
