#!/usr/bin/env bash
# Single-broadcast fast path for deploying every tutorial package at once.
#
# This is the speed-optimized sibling of scripts/deploy.sh. Instead of running
# each package's script/Deploy.s.sol as its own `forge script --broadcast`
# invocation (45 sequential confirmation waits, ~8-10 min), it runs ONE
# script/DeployAll.s.sol that deploys every package's contracts inside a single
# vm.startBroadcast()/stopBroadcast(). forge then sends all of the transactions
# with sequential nonces and waits for receipts ONCE (~1-2 blocks total).
#
# It writes the SAME outputs as deploy.sh — deployments/<network>.json and the
# faucet UI mirror docker/shared/<network>.json — by parsing the PKG:/ADDR:
# lines DeployAll emits and grouping ADDR: keys under their preceding PKG:.
#
# The deployer/faucet key conventions match deploy.sh exactly:
#   - signs with DEPLOYER_MNEMONIC account index 0 (deployer + gas payer),
#   - the faucet is DEPLOYER_MNEMONIC account index 9.
#
# Usage:
#   scripts/deploy-all.sh <network> [all|sto]
#
#   pnpm deploy:hoodi:fast              # deploy everything in one broadcast
#   pnpm deploy:base-sepolia:sto:fast   # deploy the STO subset in one broadcast
#   scripts/deploy-all.sh sepolia       # any alias in foundry.toml [rpc_endpoints]
#
# Required env (loaded from .env at the repo root if present):
#   DEPLOYER_MNEMONIC       BIP-39 phrase; account 0 is the deployer and gas payer
#   <NETWORK>_RPC_URL       RPC endpoint for the chosen network
#
# Optional env:
#   DEPLOYER_ADDRESS        if set, must match mnemonic account 0 — aborts on mismatch
#   <NETWORK>_PUBLIC_RPC_URL  student-facing RPC written into the faucet UI config

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

NETWORK="${1:-}"
DEPLOY_PROFILE="${2:-all}"

usage() {
  echo "usage: scripts/deploy-all.sh <network> [all|sto]" >&2
  echo "       network is any alias in foundry.toml [rpc_endpoints] (sepolia, hoodi, ...)" >&2
}

if [[ -z "$NETWORK" ]]; then
  echo "[deploy-all] ERROR: missing <network>" >&2
  usage
  exit 1
fi

case "$DEPLOY_PROFILE" in
  all)
    SCRIPT_TARGET="script/DeployAll.s.sol:DeployAll"
    ;;
  sto)
    if [[ "$NETWORK" != "base-sepolia" ]]; then
      echo "[deploy-all] ERROR: the sto profile is restricted to base-sepolia" >&2
      exit 1
    fi
    SCRIPT_TARGET="script/DeploySto.s.sol:DeploySto"
    ;;
  *)
    echo "[deploy-all] ERROR: unknown deploy profile '${DEPLOY_PROFILE}'" >&2
    usage
    exit 1
    ;;
esac

# Load .env so RPC URLs and the mnemonic reach forge/cast. .env provides
# defaults only: variables already set in the environment win, so explicit
# overrides like `HOODI_RPC_URL=... scripts/deploy-all.sh ...` are honored.
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
  echo "[deploy-all] ERROR: set ${RPC_ENV} in .env for network '${NETWORK}'" >&2
  exit 1
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
    echo "[deploy-all] ERROR: DEPLOYER_ADDRESS (${DEPLOYER_ADDRESS}) does not match mnemonic account 0 (${DEPLOYER_ADDR})" >&2
    exit 1
  fi
fi

CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")

# Prevent another repository deploy command from racing this broadcast for
# the same account's nonces. Transactions inside this script still use
# sequential nonces and are submitted back-to-back by Forge.
DEPLOYER_LOCK_ID=$(printf '%s' "$DEPLOYER_ADDR" | tr '[:upper:]' '[:lower:]')
DEPLOY_LOCK="${TMPDIR:-/tmp}/solidity-tutorial-deploy-${CHAIN_ID}-${DEPLOYER_LOCK_ID}.lock"
if ! mkdir "$DEPLOY_LOCK" 2>/dev/null; then
  echo "[deploy-all] ERROR: another deploy is using $DEPLOYER_ADDR on chain $CHAIN_ID" >&2
  echo "[deploy-all] lock: $DEPLOY_LOCK" >&2
  exit 1
fi
trap 'rmdir "$DEPLOY_LOCK" 2>/dev/null || true' EXIT INT TERM

echo "[deploy-all] network:  $NETWORK (chainId=$CHAIN_ID)"
echo "[deploy-all] deployer: $DEPLOYER_ADDR"
echo "[deploy-all] profile:  $DEPLOY_PROFILE"
echo "[deploy-all] mode:     single broadcast ($SCRIPT_TARGET)"

# Faucet UI mirror (docker/shared is mounted at /data in the faucet container)
# uses the addresses.json schema from docker/build-snapshot.sh. The faucet
# account follows the same convention as deploy.sh: mnemonic account #9.
FAUCET_KEY=$(cast wallet private-key "$DEPLOYER_MNEMONIC" 9)
FAUCET_ADDR=$(cast wallet address --private-key "$FAUCET_KEY")
PUBLIC_RPC_ENV="$(printf '%s' "$NETWORK" | tr 'a-z-' 'A-Z_')_PUBLIC_RPC_URL"
PUBLIC_RPC="${!PUBLIC_RPC_ENV:-}"

# Run the one-shot deploy and capture its output. FOUNDRY_PROFILE=deployall
# enables via_ir + the optimizer so the whole monorepo compiles together.
outfile=$(mktemp)
set +e
FOUNDRY_PROFILE=deployall forge script "$SCRIPT_TARGET" \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$DEPLOYER_KEY" \
  >"$outfile" 2>&1
rc=$?
set -e

cat "$outfile" >&2

if [[ $rc -ne 0 ]]; then
  echo "[deploy-all] ERROR: forge script failed (rc=${rc})" >&2
  rm -f "$outfile"
  exit 1
fi

# Group the PKG:/ADDR: emissions into a nested {"<pkg>": {"<role>": "<addr>"}}
# object. ADDR: lines belong to the most recent PKG: line above them, matching
# the order DeployAll prints them.
#
# awk emits one "pkg<TAB>role<TAB>addr" record per ADDR: line; jq folds those
# into the nested object.
packages_json=$(
  awk '
    /^[[:space:]]*PKG:/ {
      line = $0
      sub(/.*PKG:/, "", line)
      sub(/[[:space:]]*$/, "", line)
      pkg = line
      next
    }
    /ADDR:[A-Za-z0-9_]+:[[:space:]]+0x[0-9a-fA-F]+/ {
      role = $0
      sub(/.*ADDR:/, "", role)
      sub(/:.*/, "", role)
      addr = $0
      sub(/.*ADDR:[A-Za-z0-9_]+:[[:space:]]+/, "", addr)
      sub(/[^0-9a-fA-Fx].*$/, "", addr)
      if (pkg != "") {
        printf "%s\t%s\t%s\n", pkg, role, addr
      }
    }
  ' "$outfile" \
  | jq -R -s '
      [ split("\n")[] | select(length > 0) | split("\t") | {pkg: .[0], role: .[1], addr: .[2]} ]
      | reduce .[] as $r ({}; .[$r.pkg] = ((.[$r.pkg] // {}) + {($r.role): $r.addr}))
    '
)

rm -f "$outfile"

if [[ "$packages_json" == "{}" || -z "$packages_json" ]]; then
  echo "[deploy-all] ERROR: no PKG:/ADDR: lines parsed from forge output" >&2
  exit 1
fi

if [[ "$DEPLOY_PROFILE" == "sto" ]]; then
  if ! jq -e '
    (keys | sort) == ([
      "default-erc-20",
      "simple-wallet",
      "q-05-simple-wallet",
      "thirty-one-game",
      "merkle-allowlist",
      "q-20-erc20-basic",
      "q-27-merkle-allowlist"
    ] | sort)
    and ([
      .["default-erc-20"].token,
      .["simple-wallet"].wallet,
      .["q-05-simple-wallet"].wallet,
      .["q-05-simple-wallet"].token,
      .["thirty-one-game"].token,
      .["thirty-one-game"].allowlist,
      .["thirty-one-game"].game,
      .["merkle-allowlist"].token,
      .["merkle-allowlist"].allowlist,
      .["merkle-allowlist"].restrictedToken,
      .["merkle-allowlist"].distributor,
      .["q-20-erc20-basic"].lab,
      .["q-20-erc20-basic"].faucet,
      .["q-20-erc20-basic"].vault,
      .["q-27-merkle-allowlist"].lab
    ] | all(type == "string" and test("^0x[0-9a-fA-F]{40}$")))
    and .["thirty-one-game"].allowlist == .["merkle-allowlist"].allowlist
  ' <<<"$packages_json" >/dev/null; then
    echo "[deploy-all] ERROR: incomplete STO deployment output; refusing to write records" >&2
    exit 1
  fi
fi

# The shared token is default-erc-20's token address.
SHARED_TOKEN=$(jq -r '."default-erc-20".token // empty' <<<"$packages_json")

pkg_count=$(jq 'keys | length' <<<"$packages_json")
echo "[deploy-all] parsed ${pkg_count} packages; shared token: ${SHARED_TOKEN:-none}"

mkdir -p "$ROOT_DIR/deployments"
OUT="$ROOT_DIR/deployments/${NETWORK}.json"
existing="{}"
if [[ "$DEPLOY_PROFILE" == "sto" && -f "$OUT" ]]; then
  existing=$(cat "$OUT")
  if ! jq -e --argjson chainId "$CHAIN_ID" '.chainId == $chainId' <<<"$existing" >/dev/null; then
    echo "[deploy-all] ERROR: existing deployment record has a different chainId: $OUT" >&2
    exit 1
  fi
fi

# Same schema as deploy.sh's flush_record (deployments/<network>.json).
jq -n \
  --arg network "$NETWORK" \
  --argjson chainId "$CHAIN_ID" \
  --arg deployer "$DEPLOYER_ADDR" \
  --arg sharedToken "${SHARED_TOKEN:-}" \
  --argjson existing "$existing" \
  --argjson packages "$packages_json" \
  '{
     network: $network,
     chainId: $chainId,
     deployer: $deployer,
     sharedToken: (if $sharedToken == "" then null else $sharedToken end),
     packages: (($existing.packages // {}) + $packages)
   }' \
  >"$OUT"

# Faucet UI mirror (docker/shared/<network>.json), same schema as deploy.sh.
mkdir -p "$ROOT_DIR/docker/shared"
WEB_OUT="$ROOT_DIR/docker/shared/${NETWORK}.json"
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

echo "[deploy-all] wrote ${OUT}"
echo "[deploy-all] wrote ${WEB_OUT} (faucet ${FAUCET_ADDR} — fund it for live ETH drops)"
echo "[deploy-all] done"
