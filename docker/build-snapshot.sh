#!/usr/bin/env bash
# Build-time snapshot generator.
#
# Runs inside the Docker build stage:
#   1. boot a transient anvil on 127.0.0.1:8545 with the mnemonic + chainId
#      baked into the image,
#   2. run every /app/*/script/Deploy.s.sol once and assemble
#      /snapshot/addresses.json,
#   3. call anvil_dumpState and persist the compressed hex blob to
#      /snapshot/state.json,
#   4. tear anvil down.
#
# At runtime the entrypoint only has to `anvil --load-state /snapshot/state.json`
# and copy addresses.json to /shared — boot is ~1s instead of ~30s.
#
# When ANVIL_MNEMONIC or ANVIL_CHAIN_ID change as build ARGs, Docker
# invalidates this layer automatically, which re-deploys and re-dumps state.

set -euo pipefail

: "${ANVIL_MNEMONIC:?build arg ANVIL_MNEMONIC required}"
: "${ANVIL_CHAIN_ID:?build arg ANVIL_CHAIN_ID required}"

SNAPSHOT_DIR=/snapshot
ANVIL_RPC=http://127.0.0.1:8545

mkdir -p "$SNAPSHOT_DIR"

echo "[snapshot] starting transient anvil (chainId=${ANVIL_CHAIN_ID})"
# --dump-state writes the in-memory state to a JSON file on graceful shutdown.
# The cmd-line file format is what the runtime's --load-state consumes; the
# anvil_dumpState RPC returns a different (hex) format and is not compatible.
anvil \
  --host 127.0.0.1 \
  --port 8545 \
  --chain-id "$ANVIL_CHAIN_ID" \
  --mnemonic "$ANVIL_MNEMONIC" \
  --dump-state "$SNAPSHOT_DIR/state.json" \
  > /tmp/anvil.log 2>&1 &
ANVIL_PID=$!

cleanup() {
  if kill -0 "$ANVIL_PID" 2>/dev/null; then
    # SIGTERM (not KILL) so anvil flushes its state to --dump-state.
    kill -TERM "$ANVIL_PID" 2>/dev/null || true
    wait "$ANVIL_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "[snapshot] waiting for anvil RPC..."
for i in $(seq 1 60); do
  if cast block-number --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
    echo "[snapshot] anvil ready after ${i} polls"
    break
  fi
  sleep 0.5
done
if ! cast block-number --rpc-url "$ANVIL_RPC" >/dev/null 2>&1; then
  echo "[snapshot] ERROR: anvil failed to start" >&2
  cat /tmp/anvil.log >&2
  exit 1
fi

DEPLOYER_KEY=$(cast wallet private-key "$ANVIL_MNEMONIC" 0)
DEPLOYER_ADDR=$(cast wallet address --private-key "$DEPLOYER_KEY")
FAUCET_KEY=$(cast wallet private-key "$ANVIL_MNEMONIC" 9)
FAUCET_ADDR=$(cast wallet address --private-key "$FAUCET_KEY")
echo "[snapshot] deployer: ${DEPLOYER_ADDR}"
echo "[snapshot] faucet:   ${FAUCET_ADDR}"

# deploy_one <package-name> — runs one Deploy.s.sol, returns a JSON object of
# its ADDR:<key>: <0x...> emissions on stdout.
deploy_one() {
  local pkg="$1"
  echo "[snapshot] >>> deploying ${pkg}" >&2
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
    echo "[snapshot] ERROR: forge script failed for ${pkg} (rc=${rc})" >&2
    rm -f "$outfile"
    exit 1
  fi

  local pairs
  pairs=$(grep -E "ADDR:[A-Za-z0-9_]+:[[:space:]]+0x[0-9a-fA-F]+" "$outfile" \
    | sed -E 's/.*ADDR:([A-Za-z0-9_]+):[[:space:]]+(0x[0-9a-fA-F]+).*/"\1":"\2"/' || true)

  rm -f "$outfile"
  popd >/dev/null

  if [[ -z "$pairs" ]]; then
    echo "[snapshot] ERROR: no ADDR: lines found for ${pkg}" >&2
    exit 1
  fi

  echo "{$(echo "$pairs" | paste -sd,)}"
}

shopt -s nullglob
pkg_names=()
for deploy_file in /app/*/script/Deploy.s.sol; do
  pkg_dir=$(dirname "$(dirname "$deploy_file")")
  pkg_names+=("$(basename "$pkg_dir")")
done
shopt -u nullglob

if [[ ${#pkg_names[@]} -eq 0 ]]; then
  echo "[snapshot] ERROR: no script/Deploy.s.sol files found under /app/*/" >&2
  exit 1
fi

IFS=$'\n' read -r -d '' -a packages < <(printf '%s\n' "${pkg_names[@]}" | sort && printf '\0')
echo "[snapshot] discovered ${#packages[@]} packages"

challenges_json="{}"
for pkg in "${packages[@]}"; do
  pairs_json=$(deploy_one "$pkg")
  challenges_json=$(echo "$challenges_json" \
    | jq --argjson p "$pairs_json" --arg name "$pkg" '. + {($name): $p}')
done

# addresses.json — rpcPort/rpcUrl are runtime concerns, left null here so the
# entrypoint can fill them in based on the actual port the live anvil binds to.
jq -n \
  --argjson chainId "$ANVIL_CHAIN_ID" \
  --arg deployer "$DEPLOYER_ADDR" \
  --arg faucetAddr "$FAUCET_ADDR" \
  --arg faucetKey "$FAUCET_KEY" \
  --argjson challenges "$challenges_json" \
  '{
     chainId: $chainId,
     rpcPort: null,
     rpcUrl: null,
     deployer: $deployer,
     faucet: {address: $faucetAddr, privateKey: $faucetKey},
     challenges: $challenges
   }' \
  > "$SNAPSHOT_DIR/addresses.json"

echo "[snapshot] flushing anvil state to disk"
# The state.json file materializes once anvil receives SIGTERM and exits.
# Triggering that here keeps the trap's wait short and predictable.
kill -TERM "$ANVIL_PID"
wait "$ANVIL_PID" 2>/dev/null || true

if [[ ! -s "$SNAPSHOT_DIR/state.json" ]]; then
  echo "[snapshot] ERROR: anvil did not produce $SNAPSHOT_DIR/state.json" >&2
  cat /tmp/anvil.log >&2
  exit 1
fi

state_bytes=$(wc -c < "$SNAPSHOT_DIR/state.json")
echo "[snapshot] state.json: ${state_bytes} bytes"
echo "[snapshot] addresses.json challenges: $(jq '.challenges | length' "$SNAPSHOT_DIR/addresses.json")"
echo "[snapshot] done"
