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
#   VERIFY=1 pnpm deploy:sepolia all        # also verify on the block explorer
#   scripts/deploy.sh ethereum default-erc-20   # mainnets have no pnpm shortcut on purpose
#
# Required env (loaded from .env at the repo root if present):
#   DEPLOYER_MNEMONIC       BIP-39 phrase; account 0 is the deployer and gas payer
#   <NETWORK>_RPC_URL       RPC endpoint for the chosen network (see derivation above)
#   ETHERSCAN_API_KEY       only when VERIFY=1

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
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
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
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$NETWORK" \
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

  echo "{$(echo "$pairs" | paste -sd,)}"
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

# Deploy the shared ERC-20 first (if requested) and export SHARED_ERC20 so the
# token-agnostic packages pick it up via vm.envOr.
if printf '%s\n' "${packages[@]}" | grep -qx "$SHARED_TOKEN_PKG"; then
  pairs_json=$(deploy_one "$SHARED_TOKEN_PKG")
  deployments_json=$(echo "$deployments_json" \
    | jq --argjson p "$pairs_json" --arg name "$SHARED_TOKEN_PKG" '. + {($name): $p}')
  tok=$(echo "$pairs_json" | jq -r '.token // empty')
  if [[ -n "$tok" ]]; then
    export SHARED_ERC20="$tok"
    echo "[deploy] shared ERC-20 token: ${SHARED_ERC20}"
  fi
fi

for pkg in "${packages[@]}"; do
  [[ "$pkg" == "$SHARED_TOKEN_PKG" ]] && continue
  pairs_json=$(deploy_one "$pkg")
  deployments_json=$(echo "$deployments_json" \
    | jq --argjson p "$pairs_json" --arg name "$pkg" '. + {($name): $p}')
done

# Merge into deployments/<network>.json so a single-package run does not wipe
# addresses recorded by earlier runs on the same network.
mkdir -p "$ROOT_DIR/deployments"
OUT="$ROOT_DIR/deployments/${NETWORK}.json"
existing="{}"
[[ -f "$OUT" ]] && existing=$(cat "$OUT")

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

echo "[deploy] wrote ${OUT}"
echo "[deploy] done"
