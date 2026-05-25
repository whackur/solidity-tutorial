#!/usr/bin/env bash
# Solidity Tutorial — anvil + auto-deploy entrypoint.
#
# Boot anvil, wait for RPC, run every q-XX/script/Deploy.s.sol, and write
# the deployed addresses to /shared/addresses.json so a web UI or the
# instructor can hand them out.
#
# Each Deploy.s.sol must emit `console2.log("ADDR:<key>:", address)` lines.
# Those lines are parsed here and grouped into a per-challenge JSON object.

set -euo pipefail

ANVIL_HOST="${ANVIL_HOST:-0.0.0.0}"
ANVIL_PORT="${ANVIL_PORT:-8545}"
ANVIL_CHAIN_ID="${ANVIL_CHAIN_ID:-31337}"
ANVIL_MNEMONIC="${ANVIL_MNEMONIC:-test test test test test test test test test test test junk}"
ANVIL_RPC="http://127.0.0.1:${ANVIL_PORT}"
SHARED_DIR="${SHARED_DIR:-/shared}"

# anvil account #0 (deterministic from the default mnemonic).
# Public, well-known, ZERO real value. Used only for local deploys.
DEPLOYER_ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

mkdir -p "$SHARED_DIR"

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

# deploy_one <package-dir>
#   - runs forge script for the package
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

  # Surface forge output to the container log regardless of success.
  cat "$outfile" >&2

  if [[ $rc -ne 0 ]]; then
    echo "[entrypoint] ERROR: forge script failed for ${pkg} (rc=${rc})" >&2
    rm -f "$outfile"
    exit 1
  fi

  # Extract `ADDR:<key>: 0x...` lines (forge prepends a couple of spaces
  # under the `== Logs ==` section).
  local pairs
  pairs=$(grep -E "ADDR:[A-Za-z0-9_]+:[[:space:]]+0x[0-9a-fA-F]+" "$outfile" \
    | sed -E 's/.*ADDR:([A-Za-z0-9_]+):[[:space:]]+(0x[0-9a-fA-F]+).*/"\1":"\2"/')

  rm -f "$outfile"
  popd >/dev/null

  if [[ -z "$pairs" ]]; then
    echo "[entrypoint] ERROR: no ADDR: lines found for ${pkg}" >&2
    exit 1
  fi

  echo "{$(echo "$pairs" | paste -sd,)}"
}

# --- run all per-challenge deploys -----------------------------------------
Q01=$(deploy_one "q-01-counter")
Q02=$(deploy_one "q-02-events-errors")
Q03=$(deploy_one "q-03-eth-mailbox")
Q04=$(deploy_one "q-04-delegatecall")
Q05=$(deploy_one "q-05-simple-wallet")
Q06=$(deploy_one "q-06-erc20-permit")
Q07=$(deploy_one "q-07-eth-sign")
Q08=$(deploy_one "q-08-eip712-voucher")
Q09=$(deploy_one "q-09-reentrancy")
Q10=$(deploy_one "q-10-signature-replay")
Q11=$(deploy_one "q-11-access-control")
Q12=$(deploy_one "q-12-tx-origin")
Q13=$(deploy_one "q-13-unchecked-call")
Q14=$(deploy_one "q-14-dos-revert")
Q15=$(deploy_one "q-15-front-run")
Q16=$(deploy_one "q-16-oracle-spot")
Q17=$(deploy_one "q-17-reentrancy-inflate")
Q18=$(deploy_one "q-18-read-only-reentrancy")
Q19=$(deploy_one "q-19-reentrancy-basic")
# ---------------------------------------------------------------------------

cat > "$SHARED_DIR/addresses.json" <<EOF
{
  "chainId": ${ANVIL_CHAIN_ID},
  "rpcUrl": "http://localhost:${ANVIL_PORT}",
  "deployer": "${DEPLOYER_ADDR}",
  "challenges": {
    "q-01-counter": ${Q01},
    "q-02-events-errors": ${Q02},
    "q-03-eth-mailbox": ${Q03},
    "q-04-delegatecall": ${Q04},
    "q-05-simple-wallet": ${Q05},
    "q-06-erc20-permit": ${Q06},
    "q-07-eth-sign": ${Q07},
    "q-08-eip712-voucher": ${Q08},
    "q-09-reentrancy": ${Q09},
    "q-10-signature-replay": ${Q10},
    "q-11-access-control": ${Q11},
    "q-12-tx-origin": ${Q12},
    "q-13-unchecked-call": ${Q13},
    "q-14-dos-revert": ${Q14},
    "q-15-front-run": ${Q15},
    "q-16-oracle-spot": ${Q16},
    "q-17-reentrancy-inflate": ${Q17},
    "q-18-read-only-reentrancy": ${Q18},
    "q-19-reentrancy-basic": ${Q19}
  }
}
EOF

# Pretty-print with jq for validation + nicer logs.
if jq . "$SHARED_DIR/addresses.json" > "$SHARED_DIR/addresses.pretty.json" 2>/dev/null; then
  mv "$SHARED_DIR/addresses.pretty.json" "$SHARED_DIR/addresses.json"
fi

echo "[entrypoint] addresses.json written:"
cat "$SHARED_DIR/addresses.json"

echo "[entrypoint] anvil now in foreground (PID=${ANVIL_PID}). Ctrl+C to stop."
wait "$ANVIL_PID"
