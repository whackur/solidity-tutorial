#!/usr/bin/env bash
# Deploy tutorial packages to any network defined in foundry.toml [rpc_endpoints].
#
# This is the live-RPC sibling of docker/build-snapshot.sh. Instead of a
# transient anvil it targets a real network, but keeps the same conventions:
#   - signs with DEPLOYER_MNEMONIC account index 0 — the same deployer key
#     convention as simple-uups/script/Upgrade.s.sol and the docker snapshot,
#   - runs each package's script/Deploy.s.sol:Deploy with --broadcast,
#   - deploys default-erc-20 first and exports its address as SHARED_ERC20 so
#     token-agnostic packages reuse it (vm.envOr) instead of deploying a mock,
#   - assembles deployments/<network>.json from the ADDR:<key>: emissions.
#
# The network is just a name — anything wired in foundry.toml [rpc_endpoints]
# works (sepolia, hoodi, ethereum, base, optimism, ...). The RPC URL env var is
# derived from the network name: uppercase it and swap '-' for '_', then append
# _RPC_URL (e.g. base-sepolia -> BASE_SEPOLIA_RPC_URL), matching the rpc_env
# keys in config/foundry/packages.json.
#
# Usage:
#   scripts/deploy.sh <network> <package|all>
#
#   pnpm deploy:sepolia default-erc-20      # one package
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
  echo "usage: scripts/deploy.sh <network> <package|all>" >&2
  echo "       network is any alias in foundry.toml [rpc_endpoints] (sepolia, hoodi, ...)" >&2
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

# Resolve the package list: a single named package, or every package that has a
# script/Deploy.s.sol when TARGET == "all".
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
else
  if [[ ! -f "$ROOT_DIR/$TARGET/script/Deploy.s.sol" ]]; then
    echo "[deploy] ERROR: $TARGET/script/Deploy.s.sol not found" >&2
    exit 1
  fi
  packages=("$TARGET")
fi

echo "[deploy] packages: ${packages[*]}"

SHARED_TOKEN_PKG="default-erc-20"
deployments_json="{}"

# The record file is rewritten after every package so a mid-run failure (one
# broken deploy out of many) never loses the addresses already broadcast.
mkdir -p "$ROOT_DIR/deployments"
OUT="$ROOT_DIR/deployments/${NETWORK}.json"
existing="{}"
[[ -f "$OUT" ]] && existing=$(cat "$OUT")

# SKIP_DEPLOYED=1 resumes a partial run: packages already present in the
# record are skipped instead of redeployed (and re-paid for).
skip_deployed="${SKIP_DEPLOYED:-0}"

already_deployed() {
  jq -e --arg p "$1" '.packages | has($p)' <<<"$existing" >/dev/null 2>&1
}

# Challenge labs that seed user instances with multi-ETH amounts (SEED is a
# contract constant, 5-10 ETH per instance) are economically anvil-only —
# no live-network faucet budget can sustain them. Skipped by default on this
# live-RPC path; override the list via SKIP_PACKAGES (set it empty to force).
DEFAULT_LIVE_SKIP="q-09-reentrancy q-10-signature-replay q-12-tx-origin q-15-front-run q-16-oracle-spot q-17-reentrancy-inflate q-18-read-only-reentrancy q-19-reentrancy-basic"
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
    '{
       network: .network,
       chainId: .chainId,
       rpcUrl: (if $rpcUrl == "" then null else $rpcUrl end),
       dropEth: 0.002,
       maxRecipientBalanceEth: 0.01,
       deployer: .deployer,
       faucet: {address: $faucetAddr, privateKey: $faucetKey},
       sharedToken: (if .sharedToken == null then null else
         {address: .sharedToken, name: "MyERC20", symbol: "ME2", decimals: 18} end),
       challenges: .packages
     }' \
    "$OUT" >"$WEB_OUT"
}

# Deploy the shared ERC-20 first (if requested) and export SHARED_ERC20 so the
# token-agnostic packages pick it up via vm.envOr.
if printf '%s\n' "${packages[@]}" | grep -qx "$SHARED_TOKEN_PKG"; then
  if [[ "$skip_deployed" == "1" ]] && already_deployed "$SHARED_TOKEN_PKG"; then
    tok=$(jq -r '.sharedToken // empty' <<<"$existing")
    [[ -n "$tok" ]] && export SHARED_ERC20="$tok"
    echo "[deploy] skipping ${SHARED_TOKEN_PKG} (already in record); shared token: ${SHARED_ERC20:-none}"
  else
    pairs_json=$(deploy_one "$SHARED_TOKEN_PKG")
    deployments_json=$(echo "$deployments_json" \
      | jq --argjson p "$pairs_json" --arg name "$SHARED_TOKEN_PKG" '. + {($name): $p}')
    tok=$(echo "$pairs_json" | jq -r '.token // empty')
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
    echo "[deploy] skipping ${pkg} (already in record)"
    continue
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
