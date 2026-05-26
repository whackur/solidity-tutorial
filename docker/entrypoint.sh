#!/usr/bin/env bash
# Solidity Tutorial — anvil + auto-deploy entrypoint.
#
# Boot anvil, wait for RPC, run every */script/Deploy.s.sol found at depth 2,
# and write deployed addresses to /shared/addresses.json so the web UI or
# the instructor can hand them out.
#
# Each Deploy.s.sol must:
#   - declare `contract Deploy is Script`
#   - emit `console2.log("ADDR:<key>:", address)` lines for each contract
#     that should appear in addresses.json
# Folders without a Deploy.s.sol are ignored.

set -euo pipefail

ANVIL_HOST="${ANVIL_HOST:-0.0.0.0}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
ANVIL_MNEMONIC="${ANVIL_MNEMONIC:-test test test test test test test test test test test junk}"
ANVIL_RPC="http://127.0.0.1:${ANVIL_PORT}"
SHARED_DIR="${SHARED_DIR:-/shared}"

mkdir -p "$SHARED_DIR"
# Drop any addresses.json left from a previous boot — keeps stale data from
# leaking through the bind mount when this run aborts before rewriting it.
rm -f "$SHARED_DIR/addresses.json"

echo "[entrypoint] starting anvil on ${ANVIL_HOST}:${ANVIL_PORT} (chainId=${ANVIL_CHAIN_ID})"
anvil \
  --host "$ANVIL_HOST" \
  --port "$ANVIL_PORT" \
  --chain-id "$ANVIL_CHAIN_ID" \
  --mnemonic "$ANVIL_MNEMONIC" \
  > /tmp/anvil.log 2>&1 &
ANVIL_PID=$!

echo "[entrypoint] waiting for anvil to accept RPC..."
for i in $(seq 1 60); do
  if cast block-number --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
    echo "[entrypoint] anvil ready after ${i} polls"
    break
  fi
  sleep 0.5
done

if ! cast block-number --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
  echo "[entrypoint] ERROR: anvil failed to start. log:"
  cat /tmp/anvil.log
  exit 1
fi

# Derive deployer (account #0) and faucet (account #9) wallets from
# whichever mnemonic anvil was started with. Splitting accounts keeps
# faucet drops from racing the deploy nonce.
DEPLOYER_KEY=$(cast wallet private-key "$ANVIL_MNEMONIC" 0)
DEPLOYER_ADDR=$(cast wallet address --private-key "$DEPLOYER_KEY")
FAUCET_KEY=$(cast wallet private-key "$ANVIL_MNEMONIC" 9)
FAUCET_ADDR=$(cast wallet address --private-key "$FAUCET_KEY")
echo "[entrypoint] deployer: ${DEPLOYER_ADDR}"
echo "[entrypoint] faucet:   ${FAUCET_ADDR}"

# deploy_one <package-name>
#   - runs forge script Deploy.s.sol:Deploy
#   - parses ADDR:<key>: 0x... lines from the output
#   - emits a single-line JSON object on stdout: {"key1":"0x...","key2":"0x..."}
deploy_one() {
  local pkg="$1"

  echo "[entrypoint] >>> deploying ${pkg}" >&2
  pushd "/app/${pkg}" >/dev/null

  local outfile
  outfile=$(mktemp)
  set +e
  forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$DEPLOYER_KEY" \
    > "$outfile" 2>&1
  local rc=$?
  set -e

  cat "$outfile" >&2

  if [[ $rc -ne 0 ]]; then
    echo "[entrypoint] ERROR: forge script failed for ${pkg} (rc=${rc})" >&2
    rm -f "$outfile"
    exit 1
  fi

  local pairs
  pairs=$(grep -E "ADDR:[A-Za-z0-9_]+:[[:space:]]+0x[0-9a-fA-F]+" "$outfile" \
    | sed -E 's/.*ADDR:([A-Za-z0-9_]+):[[:space:]]+(0x[0-9a-fA-F]+).*/"\1":"\2"/' || true)

  rm -f "$outfile"
  popd >/dev/null

  if [[ -z "$pairs" ]]; then
    echo "[entrypoint] ERROR: no ADDR: lines found for ${pkg}" >&2
    exit 1
  fi

  echo "{$(echo "$pairs" | paste -sd,)}"
}

# --- discover every package with script/Deploy.s.sol -----------------------
shopt -s nullglob
pkg_names=()
for deploy_file in /app/*/script/Deploy.s.sol; do
  pkg_dir=$(dirname "$(dirname "$deploy_file")")
  pkg_names+=("$(basename "$pkg_dir")")
done
shopt -u nullglob

if [[ ${#pkg_names[@]} -eq 0 ]]; then
  echo "[entrypoint] ERROR: no script/Deploy.s.sol files found under /app/*/" >&2
  exit 1
fi

# Sort alphabetically for deterministic addresses.json ordering.
IFS=$'\n' read -r -d '' -a packages < <(printf '%s\n' "${pkg_names[@]}" | sort && printf '\0')

echo "[entrypoint] discovered ${#packages[@]} packages: ${packages[*]}"

# --- run all deploys, accumulate challenges JSON ---------------------------
challenges_json="{}"
for pkg in "${packages[@]}"; do
  pairs_json=$(deploy_one "$pkg")
  challenges_json=$(echo "$challenges_json" \
    | jq --argjson p "$pairs_json" --arg name "$pkg" '. + {($name): $p}')
done

# --- assemble final addresses.json -----------------------------------------
jq -n \
  --argjson chainId "$ANVIL_CHAIN_ID" \
  --argjson rpcPort "$ANVIL_PORT" \
  --arg deployer "$DEPLOYER_ADDR" \
  --arg faucetAddr "$FAUCET_ADDR" \
  --arg faucetKey "$FAUCET_KEY" \
  --argjson challenges "$challenges_json" \
  '{
     chainId: $chainId,
     rpcPort: $rpcPort,
     deployer: $deployer,
     faucet: {address: $faucetAddr, privateKey: $faucetKey},
     challenges: $challenges
   }' \
  > "$SHARED_DIR/addresses.json"

echo "[entrypoint] addresses.json written:"
cat "$SHARED_DIR/addresses.json"

echo "[entrypoint] anvil now in foreground (PID=${ANVIL_PID}). Ctrl+C to stop."
wait "$ANVIL_PID"
