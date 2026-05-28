#!/usr/bin/env bash
# Solidity Tutorial — anvil load-state entrypoint.
#
# The image was already deployed into and snapshotted by
# docker/build-snapshot.sh during `docker build`. At runtime we just:
#   1. sanity-check the runtime mnemonic against the snapshot's deployer,
#   2. publish /snapshot/addresses.json to /shared with the live RPC port,
#   3. boot anvil with --load-state so all deployable packages are already deployed
#      the moment RPC comes online.
#
# Boot time is ~1s instead of ~30s. To rebuild the snapshot after editing
# a Setup.sol or changing the mnemonic, run `docker compose up -d --build`.

set -euo pipefail

ANVIL_HOST="${ANVIL_HOST:-0.0.0.0}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
ANVIL_MNEMONIC="${ANVIL_MNEMONIC:-test test test test test test test test test test test junk}"
ANVIL_LOG_LEVEL="${ANVIL_LOG_LEVEL:-INFO}"
SHARED_DIR="${SHARED_DIR:-/shared}"
SNAPSHOT_DIR=/snapshot
LOG_FILTER="/app/docker/anvil-log-filter.awk"

if [[ ! -f "$SNAPSHOT_DIR/state.json" || ! -f "$SNAPSHOT_DIR/addresses.json" ]]; then
  echo "[entrypoint] ERROR: snapshot not found at $SNAPSHOT_DIR. Rebuild the image with 'docker compose up -d --build'." >&2
  exit 1
fi

# Sanity check: the snapshot was deployed by account #0 of the build-time
# mnemonic. If the runtime mnemonic differs, the runtime deployer key will
# not match the snapshot's pre-funded balances and faucet/admin txs will
# fail with cryptic errors. Catch that here with a clear message.
SNAPSHOT_DEPLOYER=$(jq -r .deployer "$SNAPSHOT_DIR/addresses.json")
RUNTIME_KEY=$(cast wallet private-key "$ANVIL_MNEMONIC" 0)
RUNTIME_DEPLOYER=$(cast wallet address --private-key "$RUNTIME_KEY")

if [[ "$SNAPSHOT_DEPLOYER" != "$RUNTIME_DEPLOYER" ]]; then
  cat >&2 <<EOF
[entrypoint] ERROR: runtime mnemonic does not match the baked-in snapshot.
  snapshot deployer : $SNAPSHOT_DEPLOYER
  runtime deployer  : $RUNTIME_DEPLOYER
The snapshot was deployed at build time. To pick up a new ANVIL_MNEMONIC,
rebuild with: docker compose up -d --build
EOF
  exit 1
fi

mkdir -p "$SHARED_DIR"
# Publish addresses.json with the live RPC port filled in. The snapshot's
# copy leaves rpcPort/rpcUrl null because they're runtime concerns.
jq --argjson p "$ANVIL_PORT" '. + {rpcPort: $p}' "$SNAPSHOT_DIR/addresses.json" \
  > "$SHARED_DIR/addresses.json"

echo "[entrypoint] snapshot OK — deployer ${RUNTIME_DEPLOYER}, $(jq '.challenges | length' "$SHARED_DIR/addresses.json") packages"
echo "[entrypoint] starting anvil on ${ANVIL_HOST}:${ANVIL_PORT} (chainId=${ANVIL_CHAIN_ID}, log=${ANVIL_LOG_LEVEL})"

anvil \
  --host "$ANVIL_HOST" \
  --port "$ANVIL_PORT" \
  --chain-id "$ANVIL_CHAIN_ID" \
  --mnemonic "$ANVIL_MNEMONIC" \
  --load-state "$SNAPSHOT_DIR/state.json" \
  2>&1 | awk -v level="$ANVIL_LOG_LEVEL" -v port="$ANVIL_PORT" -f "$LOG_FILTER" &
ANVIL_PID=$!

echo "[entrypoint] anvil PID=${ANVIL_PID}. Ctrl+C to stop."
wait "$ANVIL_PID"
