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
| `faucet` | `8888` | Static UI that sends 1 ETH from anvil account #0    |

Deployer account (anvil's well-known test key, **never use on mainnet**):

- `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## Common commands

```bash
docker compose logs -f anvil           # tail deploy + RPC logs
docker compose down -v && docker compose up -d --build   # reset chain
docker compose down                    # stop
```

## Deploy to a live network (Sepolia / Hoodi / …)

The local docker stack covers day-to-day work; to publish initialized contracts to a real network use `scripts/deploy.sh <network> <package|all>`. It signs with `DEPLOYER_MNEMONIC` account 0 (the same convention as the docker snapshot) and runs each package's `script/Deploy.s.sol` against the live RPC.

The network is just an alias from `foundry.toml` `[rpc_endpoints]`. Its RPC URL env var is derived from the name — uppercase and `-`→`_`, then `_RPC_URL` (`base-sepolia` → `BASE_SEPOLIA_RPC_URL`). Set what you need in `.env` (copy from `.env.sample`):

```
DEPLOYER_MNEMONIC="test test test ... junk"   # account 0 is the deployer & gas payer
SEPOLIA_RPC_URL="https://..."                 # for sepolia
HOODI_RPC_URL="https://..."                   # for hoodi
ETHERSCAN_API_KEY="..."                        # only when verifying
```

Then deploy:

```bash
pnpm deploy:sepolia default-erc-20      # one package
pnpm deploy:hoodi   all                 # every package — costs real testnet ETH
VERIFY=1 pnpm deploy:sepolia all        # also verify on the block explorer
scripts/deploy.sh ethereum default-erc-20   # any configured network; mainnets have no pnpm shortcut on purpose
```

`default-erc-20` is always deployed first and exported as `SHARED_ERC20`, so token-agnostic packages reuse it. Resulting addresses are merged into `deployments/<network>.json`. `.env` is gitignored — never commit your mnemonic.

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

Graded challenges live under `q-01-…` to `q-26-…`, all inheriting the shared
[`common/src/SolvableBase.sol`](./common/src/SolvableBase.sol) (provides
`solve()` / `solvedBy(address)` / `Solved` event on top of each puzzle's
`isSolved`). See [`q-INDEX.md`](./q-INDEX.md).
