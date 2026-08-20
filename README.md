# Solidity Tutorial

Hands-on Solidity tutorial and challenge repository with a local anvil + auto-deployed challenges.

## Run

```bash
docker compose up -d --build
```

- RPC:    `http://localhost:8545` (chainId `31337`)
- Faucet: `http://localhost:8888`
- Deployed addresses: `docker/shared/addresses.json`

Override ports/mnemonic in `.env` if needed (`cp .env.sample .env`).

## What runs

| Service  | Port   | Role                                                |
| -------- | ------ | --------------------------------------------------- |
| `anvil`  | `8545` | Local EVM node loaded from a build-time snapshot of every package `Deploy.s.sol` |
| `faucet` | `8888` | Static UI that sends 1 ETH from the faucet wallet (mnemonic account #9) |

Deployer account (anvil's well-known test key, **never use on mainnet**):

- `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

Faucet account — the wallet the UI drips ETH from, always **mnemonic account #9**:

- Local anvil: `0xa0Ee7A142d267C1f36714E4a8F75612F20a79720` (anvil's well-known account #9)
- Live networks: account #9 of your `DEPLOYER_MNEMONIC`, mirrored into `docker/shared/<network>.json`

The index is the same everywhere; only the mnemonic differs — the local stack uses `ANVIL_MNEMONIC`, live networks use `DEPLOYER_MNEMONIC`. On a live network fund this account sparingly and only with testnet ETH: its private key sits in the faucet config so the UI can sign drops.

## Common commands

```bash
docker compose logs -f anvil           # tail deploy + RPC logs
docker compose down -v && docker compose up -d --build   # reset chain
docker compose down                    # stop
```

## Deploy to a live network (Sepolia / Hoodi / …)

The local docker stack covers day-to-day work; to publish initialized contracts to a real network use `scripts/deploy.sh <network> <package|all|sto>`. It signs with `DEPLOYER_MNEMONIC` account 0 (the same convention as the docker snapshot) and runs each package's `script/Deploy.s.sol` against the live RPC. The `sto` profile is restricted to Base Sepolia and deploys only the classroom contracts.

The network is just an alias from `foundry.toml` `[rpc_endpoints]`. Its RPC URL env var is derived from the name — uppercase and `-`→`_`, then `_RPC_URL` (`base-sepolia` → `BASE_SEPOLIA_RPC_URL`). Set what you need in `.env` (copy from `.env.sample`):

```
DEPLOYER_MNEMONIC="test test test ... junk"   # account 0 is the deployer & gas payer
SEPOLIA_RPC_URL="https://..."                 # for sepolia
HOODI_RPC_URL="https://..."                   # for hoodi
ETHERSCAN_API_KEY="..."                        # only when verifying
```

Then deploy:

```bash
pnpm deploy:base-sepolia default-erc-20 # one package on Base Sepolia
pnpm deploy:base-sepolia:sto            # curated STO classroom subset
pnpm deploy:base-sepolia:sto:fast       # same subset, one nonce-safe broadcast
pnpm deploy:base-sepolia:sto:verify     # subset plus Basescan verification
pnpm deploy:base-sepolia:fast           # every package, one broadcast
pnpm deploy:sepolia default-erc-20      # one package
pnpm deploy:hoodi   all                 # every package — costs real testnet ETH
VERIFY=1 pnpm deploy:sepolia all        # also verify on the block explorer
scripts/deploy.sh ethereum default-erc-20   # any configured network; mainnets have no pnpm shortcut on purpose
```

The generic `all` profile deploys `default-erc-20` first and exports it as `SHARED_ERC20`. The STO profile excludes that token and exports `BlocklistRestrictedToken` from `transfer-blocklist` instead. Resulting addresses are merged into `deployments/<network>.json` and mirrored to `docker/shared/<network>.json` so the faucet UI shows a tab for that network. `.env` is gitignored — never commit your mnemonic.

The STO profile deploys these packages in dependency order: `transfer-blocklist`, `simple-wallet`, `q-05-simple-wallet`, `thirty-one-game`, `q-20-erc20-basic`, and `q-27-merkle-allowlist`. `BlocklistRestrictedToken` is the only shared classroom token used by q-05 and the game. Transfers are allowed by default; the blocklist owner can stop the next incoming or outgoing transfer for a selected address. `q-20-erc20-basic` intentionally retains its self-contained hand-written token because implementing that token is the exercise itself. The `:fast` command runs `script/DeploySto.s.sol` under one broadcast: Forge assigns sequential nonces and submits the transactions back-to-back, avoiding nonce races between parallel deploy processes. Both deploy paths take a per-chain, per-deployer process lock; do not use the deployer account from another repository or wallet while a deployment is running. STO migration removes old `default-erc-20` and `merkle-allowlist` deployment entries from the UI record.

The blocklist is deliberately a simplified operational control, not complete STO compliance. Production designs commonly combine identity or eligibility checks with freezes, sanctions screening, limits, recovery, forced transfers, and off-chain review procedures.

### Fast path: one broadcast

`pnpm deploy:hoodi all` runs each package's `Deploy.s.sol` as a separate broadcast, so every package pays its own on-chain confirmation (~45 sequential round-trips). To deploy every package in a **single** broadcast — one confirmation cycle, much faster — use the combined script:

```bash
pnpm deploy:hoodi:fast      # bash scripts/deploy-all.sh hoodi
pnpm deploy:base-sepolia:sto:fast
```

It runs the root `script/DeployAll.s.sol` under the `deployall` Foundry profile and writes the same `deployments/<network>.json` / `docker/shared/<network>.json`. Because all lab funding happens in one tx batch, the deployer must hold the full funding up front.

### Funding and resuming

A full `all` run costs real testnet ETH — fund the deployer (mnemonic account 0) with **~1.5 ETH** before starting. Most of that is lab seeding: `q-16-oracle-spot` alone injects 1 ETH (it seeds many per-user instances), and `q-09 / q-17 / q-18 / q-19` add `0.1 / 0.05 / 0.1 / 0.1`.

If a run stops partway (e.g. the deployer runs low on gas), resume without re-paying for what already landed:

```bash
SKIP_DEPLOYED=1 pnpm deploy:hoodi all                    # skip packages already in deployments/<network>.json
SKIP_PACKAGES="q-16-oracle-spot" pnpm deploy:hoodi all   # skip specific expensive labs
```

`SKIP_DEPLOYED=1` reuses the profile-specific `sharedToken`: `default-erc-20` for generic deployments and `BlocklistRestrictedToken` for STO.

## Collect ABIs

Build every package and aggregate project-owned ABIs into one tree:

```bash
./scripts/collect-abi.sh
# → combined-out/<package>/<SourceFile.sol>/<ContractName>.json
```

Only artifacts whose source lives under each package's `src/` / `script/` /
`test/` are copied — `forge-std`, OpenZeppelin, and other dependency ABIs are
skipped. The output directory is gitignored.

## Examples

- **counter**: Counter / SimpleStorage / EventsAndErrors — event (0~3 indexed + anonymous) and error (require / revert / custom / assert / auto-Panic) showcase.
- **tx-basics**: ETH transfer and execution: transfer/send/call, delegatecall, receive/fallback.
- **simple-wallet**: Simple wallet implementation.
- **thirty-one-game**: A simple game contract.
- **transfer-blocklist**: Default-allow transfer policy with explicit address blocks.
- **default-erc-20**: Basic ERC20.
- **default-erc-721**: Basic ERC721 (ERC721 + ERC721URIStorage).
- **erc20-extended**: ERC-20 with Permit + Votes + Burnable + Capped + Pausable + Ownable combined.
- **erc1155-multi-token**: ERC-1155 multi-token (FT/NFT mix, mintBatch, safeBatchTransferFrom, uri(id)).
- **eth-sign**: Ethereum signing (EIP-191 prefix variants).
- **eip-712-voucher**: EIP-712 vouchers.
- **access-control**: Ownable vs AccessControl (MINTER_ROLE / PAUSER_ROLE split).
- **vulnerabilities**: 4 attack-vs-patch pairs — Reentrancy, tx.origin, Signature replay, Oracle manipulation.
- **minimal-proxy**: Minimal Proxy (EIP-1167).
- **simple-transparent**: Transparent Proxy upgrade pattern.
- **simple-uups**: UUPS Upgradeable contract.
- **beacon-proxy**: Beacon Proxy upgrade pattern.
- **erc2771-meta-tx**: ERC-2771 meta-transaction forwarder + recipient.
- **smart-account**: EIP-7702 smart account with ERC-7201 namespaced storage + ERC-1271.
- **merkle-allowlist**: Merkle-root allowlist gate + pull-based merkle distributor (root commitment, proof verification, claim bitmap).

Graded challenges live under `q-01-…` to `q-27-…`, all inheriting the shared
[`common/src/SolvableBase.sol`](./common/src/SolvableBase.sol) (provides
`solve()` / `solvedBy(address)` / `Solved` event on top of each puzzle's
`isSolved`). See [`q-INDEX.md`](./q-INDEX.md).
