#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/sto-profile.sh
source "$ROOT_DIR/scripts/sto-profile.sh"

fail() {
  echo "[test-sto-profile] FAIL: $1" >&2
  exit 1
}

sto_require_base_sepolia_chain "84532" || fail "Base Sepolia chain ID rejected"
if sto_require_base_sepolia_chain "11155111"; then
  fail "wrong chain ID accepted"
fi

sto_require_plain_eoa_code "0x" || fail "plain EOA code rejected"
if sto_require_plain_eoa_code "0xef01001234567890"; then
  fail "delegated account code accepted"
fi
if sto_require_plain_eoa_code "0x60006000"; then
  fail "contract code accepted"
fi

valid=$(jq -n '
  def addr($n): ("0x" + (("0000000000000000000000000000000000000000" + ($n|tostring))[-40:]));
  {
    "transfer-blocklist": {token: addr(1), blocklist: addr(2), restrictedToken: addr(1)},
    counter: {counter: addr(3), eventsAndErrors: addr(4), simpleStorage: addr(5)},
    "simple-wallet": {wallet: addr(6)},
    "q-01-counter": {counter: addr(7)},
    "q-05-simple-wallet": {wallet: addr(8), token: addr(1)},
    "thirty-one-game": {token: addr(1), game: addr(9)},
    "q-20-erc20-basic": {lab: addr(10), faucet: addr(11), vault: addr(12)},
    "merkle-allowlist": {allowlist: addr(13), restrictedToken: addr(14)},
    "q-27-merkle-allowlist": {lab: addr(16)}
  }
')
sto_validate_packages_json "$valid" || fail "valid STO schema rejected"

zero_address=$(jq '.counter.counter = "0x0000000000000000000000000000000000000000"' <<<"$valid")
if sto_validate_packages_json "$zero_address"; then
  fail "zero address accepted"
fi

filtered=$(sto_filter_existing "$(jq -n '{packages: {"q-20-erc20-basic": {}, "default-erc-20": {}, counter: {}}}')")
jq -e '.packages | has("q-20-erc20-basic") and has("counter") and (has("default-erc-20") | not)' <<<"$filtered" \
  >/dev/null || fail "STO record filter did not preserve q20 or remove non-STO package"

echo "[test-sto-profile] all checks passed"
