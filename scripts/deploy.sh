#!/usr/bin/env bash
# Deploy tutorial packages to any network defined in foundry.toml [rpc_endpoints].
#
# This is the live-RPC sibling of docker/build-snapshot.sh. Instead of a
# transient anvil it targets a real network, but keeps the same conventions:
#   - signs with DEPLOYER_MNEMONIC account index 0 — the same deployer key
#     convention as simple-uups/script/Upgrade.s.sol and the docker snapshot,
#   - runs each package's script/Deploy.s.sol:Deploy with --broadcast,
#   - generic all deploys default-erc-20 first; STO deploys transfer-blocklist
#     first and exports its restricted token as SHARED_ERC20,
#   - assembles deployments/<network>.json from the ADDR:<key>: emissions.
#
# The network is just a name — anything wired in foundry.toml [rpc_endpoints]
# works (sepolia, hoodi, ethereum, base, optimism, ...). The RPC URL env var is
# derived from the network name: uppercase it and swap '-' for '_', then append
# _RPC_URL (e.g. base-sepolia -> BASE_SEPOLIA_RPC_URL), matching the rpc_env
# keys in config/foundry/packages.json.
#
# Usage:
#   scripts/deploy.sh <network> <package|all|sto>
#
#   pnpm deploy:sepolia default-erc-20      # one package
#   pnpm deploy:base-sepolia:sto            # STO classroom subset
#   pnpm deploy:hoodi   all                 # every package (costs real testnet ETH)
#   pnpm deploy:hoodi:verify all            # deploy everything and verify on the explorer
#   VERIFY=1 pnpm deploy:sepolia all        # verify works on any network the same way
#   scripts/deploy.sh ethereum default-erc-20   # mainnets have no pnpm shortcut on purpose
#
# Required env (loaded from .env at the repo root if present):
#   DEPLOYER_MNEMONIC       BIP-39 phrase; account 0 is the deployer and gas payer
#   <NETWORK>_RPC_URL       RPC endpoint for the chosen network (see derivation above)
#   ETHERSCAN_API_KEY       only when VERIFY=1
#
# Optional env:
#   DEPLOYER_ADDRESS        if set, must match the address derived from
#                           DEPLOYER_MNEMONIC account 0 — aborts on mismatch
#   SKIP_DEPLOYED=1         resume mode — skip packages already present in
#                           deployments/<network>.json instead of redeploying
#   SKIP_PACKAGES           space-separated packages to skip; defaults to the
#                           anvil-only ETH-heavy labs (set "" to force all)
#   <NETWORK>_PUBLIC_RPC_URL  student-facing RPC written into the faucet UI
#                           config (docker/shared/<network>.json)

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

NETWORK="${1:-}"
TARGET="${2:-}"

usage() {
  echo "usage: scripts/deploy.sh <network> <package|all|sto>" >&2
  echo "       network is any alias in foundry.toml [rpc_endpoints] (sepolia, hoodi, ...)" >&2
  echo "       sto deploys the Base Sepolia classroom subset" >&2
  echo "       VERIFY=1 to also verify on the block explorer" >&2
}

if [[ -z "$NETWORK" ]]; then
  echo "[deploy] ERROR: missing <network>" >&2
  usage
  exit 1
fi

if [[ -z "$TARGET" ]]; then
  echo "[deploy] ERROR: missing <package|all>" >&2
  usage
  exit 1
fi

# Load .env so RPC URLs, the mnemonic, and the explorer key reach forge/cast.
# .env provides defaults only: variables already set in the environment win, so
# explicit overrides like `HOODI_RPC_URL=... scripts/deploy.sh ...` are honored.
if [[ -f .env ]]; then
  _pre_env=$(export -p)
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  eval "$_pre_env"
  unset _pre_env
fi

: "${DEPLOYER_MNEMONIC:?set DEPLOYER_MNEMONIC in .env}"

# Derive the RPC URL env var name from the network: base-sepolia -> BASE_SEPOLIA_RPC_URL.
RPC_ENV="$(printf '%s' "$NETWORK" | tr 'a-z-' 'A-Z_')_RPC_URL"
RPC_URL="${!RPC_ENV:-}"
if [[ -z "$RPC_URL" ]]; then
  echo "[deploy] ERROR: set ${RPC_ENV} in .env for network '${NETWORK}'" >&2
  exit 1
fi

do_verify=0
verify_flags=()
if [[ "${VERIFY:-0}" == "1" ]]; then
  : "${ETHERSCAN_API_KEY:?VERIFY=1 requires ETHERSCAN_API_KEY in .env}"
  do_verify=1
  verify_flags=(--verify)
fi

# SLOW=1 sends one tx at a time, waiting for each receipt — required when the
# deployer is an EIP-7702 delegated account (which rejects gapped-nonce txs) or
# on RPCs with laggy nonce propagation.
slow_flags=()
[[ "${SLOW:-0}" == "1" ]] && slow_flags=(--slow)

DEPLOYER_KEY=$(cast wallet private-key "$DEPLOYER_MNEMONIC" 0)
DEPLOYER_ADDR=$(cast wallet address --private-key "$DEPLOYER_KEY")

# Guard against signing with the wrong key: when DEPLOYER_ADDRESS is set it must
# match the address derived from the mnemonic (compare case-insensitively, the
# derived address is EIP-55 checksummed).
if [[ -n "${DEPLOYER_ADDRESS:-}" ]]; then
  expected=$(printf '%s' "$DEPLOYER_ADDRESS" | tr '[:upper:]' '[:lower:]')
  derived=$(printf '%s' "$DEPLOYER_ADDR" | tr '[:upper:]' '[:lower:]')
  if [[ "$expected" != "$derived" ]]; then
    echo "[deploy] ERROR: DEPLOYER_ADDRESS (${DEPLOYER_ADDRESS}) does not match mnemonic account 0 (${DEPLOYER_ADDR})" >&2
    exit 1
  fi
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")

# Prevent two repository deploy commands from using the same account and
# network concurrently. Parallel Forge processes can reserve overlapping
# nonces even when each process is internally correct.
DEPLOYER_LOCK_ID=$(printf '%s' "$DEPLOYER_ADDR" | tr '[:upper:]' '[:lower:]')
DEPLOY_LOCK="${TMPDIR:-/tmp}/solidity-tutorial-deploy-${CHAIN_ID}-${DEPLOYER_LOCK_ID}.lock"
if ! mkdir "$DEPLOY_LOCK" 2>/dev/null; then
  echo "[deploy] ERROR: another deploy is using $DEPLOYER_ADDR on chain $CHAIN_ID" >&2
  echo "[deploy] lock: $DEPLOY_LOCK" >&2
  exit 1
fi
trap 'rmdir "$DEPLOY_LOCK" 2>/dev/null || true' EXIT INT TERM

echo "[deploy] network:  $NETWORK (chainId=$CHAIN_ID)"
echo "[deploy] deployer: $DEPLOYER_ADDR"
echo "[deploy] verify:   $([[ $do_verify -eq 1 ]] && echo yes || echo no)"

# deploy_one <package> — runs one Deploy.s.sol against the live RPC and prints a
# JSON object of its ADDR:<key>: <0x...> emissions on stdout.
deploy_one() {
  local pkg="$1"
  echo "[deploy] >>> deploying ${pkg}" >&2
  pushd "$ROOT_DIR/${pkg}" >/dev/null

  local outfile
  outfile=$(mktemp)
  set +e
  # Pass the resolved URL, not the network alias: alias resolution would
  # require [rpc_endpoints] in every package's foundry.toml, which the q-*
  # challenge packages intentionally do not generate.
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$DEPLOYER_KEY" \
    "${verify_flags[@]+"${verify_flags[@]}"}" \
    "${slow_flags[@]+"${slow_flags[@]}"}" \
    >"$outfile" 2>&1
  local rc=$?
  set -e

  cat "$outfile" >&2

  if [[ $rc -ne 0 ]]; then
    echo "[deploy] ERROR: forge script failed for ${pkg} (rc=${rc})" >&2
    rm -f "$outfile"
    popd >/dev/null
    exit 1
  fi

  local pairs
  pairs=$(grep -E "ADDR:[A-Za-z0-9_]+:[[:space:]]+0x[0-9a-fA-F]+" "$outfile" \
    | sed -E 's/.*ADDR:([A-Za-z0-9_]+):[[:space:]]+(0x[0-9a-fA-F]+).*/"\1":"\2"/' || true)

  rm -f "$outfile"
  popd >/dev/null

  if [[ -z "$pairs" ]]; then
    echo "[deploy] ERROR: no ADDR: lines found for ${pkg}" >&2
    exit 1
  fi

  # BSD paste needs the explicit '-' stdin operand (GNU tolerates omitting it).
  echo "{$(echo "$pairs" | paste -sd, -)}"
}

# Resolve the package list: a single named package, every deployable package,
# or the curated Base Sepolia subset used by the STO classroom.
packages=()
if [[ "$TARGET" == "all" ]]; then
  shopt -s nullglob
  for deploy_file in "$ROOT_DIR"/*/script/Deploy.s.sol; do
    packages+=("$(basename "$(dirname "$(dirname "$deploy_file")")")")
  done
  shopt -u nullglob
  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "[deploy] ERROR: no */script/Deploy.s.sol found" >&2
    exit 1
  fi
  IFS=$'\n' read -r -d '' -a packages < <(printf '%s\n' "${packages[@]}" | sort && printf '\0')
elif [[ "$TARGET" == "sto" ]]; then
  if [[ "$NETWORK" != "base-sepolia" ]]; then
    echo "[deploy] ERROR: the sto profile is restricted to base-sepolia" >&2
    exit 1
  fi

  packages=(
    "transfer-blocklist"
    "simple-wallet"
    "q-05-simple-wallet"
    "thirty-one-game"
    "q-20-erc20-basic"
    "q-27-merkle-allowlist"
  )

  for pkg in "${packages[@]}"; do
    if [[ ! -f "$ROOT_DIR/$pkg/script/Deploy.s.sol" ]]; then
      echo "[deploy] ERROR: STO package $pkg/script/Deploy.s.sol not found" >&2
      exit 1
    fi
  done
else
  if [[ ! -f "$ROOT_DIR/$TARGET/script/Deploy.s.sol" ]]; then
    echo "[deploy] ERROR: $TARGET/script/Deploy.s.sol not found" >&2
    exit 1
  fi
  packages=("$TARGET")
fi

echo "[deploy] packages: ${packages[*]}"

if [[ "$TARGET" == "sto" ]]; then
  SHARED_TOKEN_PKG="transfer-blocklist"
  SHARED_TOKEN_NAME="Blocklist Restricted Token"
  SHARED_TOKEN_SYMBOL="BLRT"
  SHARED_TOKEN_CLASSROOM_MINT=true
else
  SHARED_TOKEN_PKG="default-erc-20"
  SHARED_TOKEN_NAME="MyERC20"
  SHARED_TOKEN_SYMBOL="ME2"
  SHARED_TOKEN_CLASSROOM_MINT=false
fi
deployments_json="{}"

# The record file is rewritten after every package so a mid-run failure (one
# broken deploy out of many) never loses the addresses already broadcast.
mkdir -p "$ROOT_DIR/deployments"
OUT="$ROOT_DIR/deployments/${NETWORK}.json"
existing="{}"
[[ -f "$OUT" ]] && existing=$(cat "$OUT")
if [[ "$TARGET" == "sto" ]]; then
  existing=$(jq 'del(.packages["default-erc-20"], .packages["merkle-allowlist"])' <<<"$existing")
fi

# SKIP_DEPLOYED=1 resumes a partial run: packages already present in the
# record are skipped instead of redeployed (and re-paid for).
skip_deployed="${SKIP_DEPLOYED:-0}"

already_deployed() {
  jq -e --arg p "$1" '.packages | has($p)' <<<"$existing" >/dev/null 2>&1
}

# Previously the value-heavy challenge labs were anvil-only — q-09/16/17/18/19
# seeded 5-10 ETH per instance and q-10/12/15 paid out ETH, so no live faucet
# budget could sustain them. They have since been scaled down (≤1 ETH lab
# funding total) and the value-only ones tokenized to a free-mint ERC-20, so all
# are now affordable on live networks. Nothing is skipped by default; override
# via SKIP_PACKAGES (e.g. SKIP_PACKAGES="q-16-oracle-spot") to exclude any.
DEFAULT_LIVE_SKIP=""
skip_packages="${SKIP_PACKAGES-$DEFAULT_LIVE_SKIP}"

is_live_skipped() {
  case " ${skip_packages} " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Faucet UI mirror (docker/shared is mounted at /data in the faucet
# container) uses the addresses.json schema from docker/build-snapshot.sh.
# The faucet account follows the same convention: mnemonic account #9 — fund
# it on the live network for drops to work. <NETWORK>_PUBLIC_RPC_URL (e.g.
# HOODI_PUBLIC_RPC_URL) sets the student-facing RPC; when unset the web app
# falls back to its built-in public default.
FAUCET_KEY=$(cast wallet private-key "$DEPLOYER_MNEMONIC" 9)
FAUCET_ADDR=$(cast wallet address --private-key "$FAUCET_KEY")
PUBLIC_RPC_ENV="$(printf '%s' "$NETWORK" | tr 'a-z-' 'A-Z_')_PUBLIC_RPC_URL"
PUBLIC_RPC="${!PUBLIC_RPC_ENV:-}"
mkdir -p "$ROOT_DIR/docker/shared"
WEB_OUT="$ROOT_DIR/docker/shared/${NETWORK}.json"

flush_record() {
  jq -n \
    --arg network "$NETWORK" \
    --argjson chainId "$CHAIN_ID" \
    --arg deployer "$DEPLOYER_ADDR" \
    --arg sharedToken "${SHARED_ERC20:-}" \
    --argjson existing "$existing" \
    --argjson new "$deployments_json" \
    '{
       network: $network,
       chainId: $chainId,
       deployer: $deployer,
       sharedToken: (if $sharedToken == "" then ($existing.sharedToken // null) else $sharedToken end),
       packages: (($existing.packages // {}) + $new)
     }' \
    >"$OUT"

  # Mirror into the faucet UI data dir on every flush so the web page tracks
  # a long `all` run package-by-package.
  jq \
    --arg rpcUrl "$PUBLIC_RPC" \
    --arg faucetAddr "$FAUCET_ADDR" \
    --arg faucetKey "$FAUCET_KEY" \
    --arg tokenName "$SHARED_TOKEN_NAME" \
    --arg tokenSymbol "$SHARED_TOKEN_SYMBOL" \
    --argjson classroomMint "$SHARED_TOKEN_CLASSROOM_MINT" \
    '{
       network: .network,
       chainId: .chainId,
       rpcUrl: (if $rpcUrl == "" then null else $rpcUrl end),
       dropEth: 0.002,
       maxRecipientBalanceEth: 0.01,
       deployer: .deployer,
       faucet: {address: $faucetAddr, privateKey: $faucetKey},
       sharedToken: (if .sharedToken == null then null else
         {address: .sharedToken, name: $tokenName, symbol: $tokenSymbol, decimals: 18,
          classroomMint: $classroomMint} end),
       challenges: .packages
     }' \
    "$OUT" >"$WEB_OUT"
}

prepare_recorded_sto_shared() {
  tok=$(jq -r '.packages["transfer-blocklist"].restrictedToken // empty' <<<"$existing")
  recorded_token_alias=$(jq -r '.packages["transfer-blocklist"].token // empty' <<<"$existing")
  recorded_blocklist=$(jq -r '.packages["transfer-blocklist"].blocklist // empty' <<<"$existing")

  [[ "$tok" =~ ^0x[0-9a-fA-F]{40}$ ]] || return 1
  [[ "$recorded_blocklist" =~ ^0x[0-9a-fA-F]{40}$ ]] || return 1

  tok_normalized=$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')
  alias_normalized=$(printf '%s' "$recorded_token_alias" | tr '[:upper:]' '[:lower:]')
  [[ "$tok_normalized" == "$alias_normalized" ]] || return 1

  token_blocklist=$(cast call "$tok" 'blocklist()(address)' --rpc-url "$RPC_URL" 2>/dev/null) \
    || return 1
  blocklist_normalized=$(printf '%s' "$recorded_blocklist" | tr '[:upper:]' '[:lower:]')
  token_blocklist_normalized=$(printf '%s' "$token_blocklist" | tr '[:upper:]' '[:lower:]')
  [[ "$blocklist_normalized" == "$token_blocklist_normalized" ]] || return 1

  blocklist_owner=$(cast call "$recorded_blocklist" 'owner()(address)' --rpc-url "$RPC_URL" 2>/dev/null) \
    || return 1
  owner_normalized=$(printf '%s' "$blocklist_owner" | tr '[:upper:]' '[:lower:]')
  deployer_normalized=$(printf '%s' "$DEPLOYER_ADDR" | tr '[:upper:]' '[:lower:]')
  [[ "$owner_normalized" == "$deployer_normalized" ]] || return 1

  cast call "$recorded_blocklist" 'isBlocked(address)(bool)' "$DEPLOYER_ADDR" \
    --rpc-url "$RPC_URL" >/dev/null 2>&1 || return 1
  cast call "$tok" 'mint(address,uint256)' "$DEPLOYER_ADDR" 0 \
    --from "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" >/dev/null 2>&1 || return 1
}

# Deploy the profile's shared token package first and export SHARED_ERC20 so
# token-agnostic packages pick it up via vm.envOr.
if printf '%s\n' "${packages[@]}" | grep -qx "$SHARED_TOKEN_PKG"; then
  reuse_shared=0
  if [[ "$skip_deployed" == "1" ]] && already_deployed "$SHARED_TOKEN_PKG"; then
    if [[ "$TARGET" == "sto" ]]; then
      if prepare_recorded_sto_shared; then
        pairs_json=$(jq -c '.packages["transfer-blocklist"]' <<<"$existing")
        deployments_json=$(echo "$deployments_json" \
          | jq --argjson p "$pairs_json" --arg name "$SHARED_TOKEN_PKG" '. + {($name): $p}')
        reuse_shared=1
      else
        echo "[deploy] redeploying ${SHARED_TOKEN_PKG} (legacy or inconsistent STO record)"
      fi
    else
      tok=$(jq -r '.sharedToken // empty' <<<"$existing")
      reuse_shared=1
    fi
  fi

  if [[ "$reuse_shared" == "1" ]]; then
    [[ -n "$tok" ]] && export SHARED_ERC20="$tok"
    echo "[deploy] skipping ${SHARED_TOKEN_PKG} (already in record); shared token: ${SHARED_ERC20:-none}"
    [[ "$TARGET" == "sto" ]] && flush_record
  else
    pairs_json=$(deploy_one "$SHARED_TOKEN_PKG")
    deployments_json=$(echo "$deployments_json" \
      | jq --argjson p "$pairs_json" --arg name "$SHARED_TOKEN_PKG" '. + {($name): $p}')
    if [[ "$TARGET" == "sto" ]]; then
      tok=$(jq -r '.restrictedToken // empty' <<<"$pairs_json")
      token_alias=$(jq -r '.token // empty' <<<"$pairs_json")
      blocklist=$(jq -r '.blocklist // empty' <<<"$pairs_json")
      tok_normalized=$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')
      alias_normalized=$(printf '%s' "$token_alias" | tr '[:upper:]' '[:lower:]')
      if [[ ! "$tok" =~ ^0x[0-9a-fA-F]{40}$ \
        || ! "$blocklist" =~ ^0x[0-9a-fA-F]{40}$ \
        || "$tok_normalized" != "$alias_normalized" ]]; then
        echo "[deploy] ERROR: transfer-blocklist emitted invalid deployment addresses" >&2
        exit 1
      fi
    else
      tok=$(jq -r '.token // empty' <<<"$pairs_json")
    fi
    if [[ -n "$tok" ]]; then
      export SHARED_ERC20="$tok"
      echo "[deploy] shared ERC-20 token: ${SHARED_ERC20}"
    fi
    flush_record
  fi
fi

for pkg in "${packages[@]}"; do
  [[ "$pkg" == "$SHARED_TOKEN_PKG" ]] && continue
  if is_live_skipped "$pkg"; then
    echo "[deploy] skipping ${pkg} (anvil-only lab — see DEFAULT_LIVE_SKIP)"
    continue
  fi
  if [[ "$skip_deployed" == "1" ]] && already_deployed "$pkg"; then
    dependency_matches=1
    if [[ "$TARGET" == "sto" && "$pkg" =~ ^(q-05-simple-wallet|thirty-one-game)$ ]]; then
      recorded_token=$(jq -r --arg p "$pkg" '.packages[$p].token // empty' <<<"$existing")
      recorded_token_normalized=$(printf '%s' "$recorded_token" | tr '[:upper:]' '[:lower:]')
      shared_token_normalized=$(printf '%s' "$SHARED_ERC20" | tr '[:upper:]' '[:lower:]')
      [[ "$recorded_token_normalized" == "$shared_token_normalized" ]] \
        || dependency_matches=0
    fi
    if [[ "$dependency_matches" == "1" ]]; then
      echo "[deploy] skipping ${pkg} (already in record)"
      continue
    fi
    echo "[deploy] redeploying ${pkg} (shared STO token changed)"
  fi
  pairs_json=$(deploy_one "$pkg")
  deployments_json=$(echo "$deployments_json" \
    | jq --argjson p "$pairs_json" --arg name "$pkg" '. + {($name): $p}')
  flush_record
done

flush_record
echo "[deploy] wrote ${OUT}"
echo "[deploy] wrote ${WEB_OUT} (faucet ${FAUCET_ADDR} — fund it for live ETH drops)"
echo "[deploy] done"
