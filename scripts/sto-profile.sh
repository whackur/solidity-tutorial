#!/usr/bin/env bash

# Base Sepolia STO classroom deployment contract shared by deploy.sh and
# deploy-all.sh. Keep this list and schema in lockstep with DeploySto.s.sol.

STO_PACKAGES=(
  "transfer-blocklist"
  "counter"
  "simple-wallet"
  "q-01-counter"
  "q-05-simple-wallet"
  "thirty-one-game"
  "q-20-erc20-basic"
  "merkle-allowlist"
  "q-27-merkle-allowlist"
)

STO_EXPECTED_PACKAGES_JSON='[
  "transfer-blocklist",
  "counter",
  "simple-wallet",
  "q-01-counter",
  "q-05-simple-wallet",
  "thirty-one-game",
  "q-20-erc20-basic",
  "merkle-allowlist",
  "q-27-merkle-allowlist"
]'

STO_EXPECTED_SCHEMA_JSON='{
  "transfer-blocklist": ["token", "blocklist", "restrictedToken"],
  "counter": ["counter", "eventsAndErrors", "simpleStorage"],
  "simple-wallet": ["wallet"],
  "q-01-counter": ["counter"],
  "q-05-simple-wallet": ["wallet", "token"],
  "thirty-one-game": ["token", "game"],
  "q-20-erc20-basic": ["lab", "faucet", "vault"],
  "merkle-allowlist": ["token", "allowlist", "restrictedToken", "distributor"],
  "q-27-merkle-allowlist": ["lab"]
}'

sto_require_base_sepolia_chain() {
  [[ "$1" == "84532" ]]
}

sto_require_plain_eoa_code() {
  [[ "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" == "0x" ]]
}

# Keep a previous deployment record resumable while removing packages from a
# different profile.
sto_filter_existing() {
  jq --argjson allowed "$STO_EXPECTED_PACKAGES_JSON" \
    '.packages = ((.packages // {}) | with_entries(select(.key as $pkg | ($allowed | index($pkg)))))' \
    <<<"$1"
}

# Validate both the package set and every per-package role emitted by either
# deployment path before a deployment record is accepted.
sto_validate_packages_json() {
  jq -e \
    --argjson expected "$STO_EXPECTED_PACKAGES_JSON" \
    --argjson schema "$STO_EXPECTED_SCHEMA_JSON" '
      . as $root
      | (type == "object")
      and (($root | keys | sort) == ($expected | sort))
      and all($expected[];
        . as $pkg
        | ($root[$pkg] | type == "object" and ((keys | sort) == ($schema[$pkg] | sort))))
      and ([
        $root["transfer-blocklist"].token,
        $root["transfer-blocklist"].blocklist,
        $root["transfer-blocklist"].restrictedToken,
        $root.counter.counter,
        $root.counter.eventsAndErrors,
        $root.counter.simpleStorage,
        $root["simple-wallet"].wallet,
        $root["q-01-counter"].counter,
        $root["q-05-simple-wallet"].wallet,
        $root["q-05-simple-wallet"].token,
        $root["thirty-one-game"].token,
        $root["thirty-one-game"].game,
        $root["q-20-erc20-basic"].lab,
        $root["q-20-erc20-basic"].faucet,
        $root["q-20-erc20-basic"].vault,
        $root["merkle-allowlist"].token,
        $root["merkle-allowlist"].allowlist,
        $root["merkle-allowlist"].restrictedToken,
        $root["merkle-allowlist"].distributor,
        $root["q-27-merkle-allowlist"].lab
      ] | all(
        type == "string"
        and test("^0x[0-9a-fA-F]{40}$")
        and ascii_downcase != "0x0000000000000000000000000000000000000000"
      ))
      and ($root["transfer-blocklist"].token | ascii_downcase) == ($root["transfer-blocklist"].restrictedToken | ascii_downcase)
      and ($root["q-05-simple-wallet"].token | ascii_downcase) == ($root["transfer-blocklist"].restrictedToken | ascii_downcase)
      and ($root["thirty-one-game"].token | ascii_downcase) == ($root["transfer-blocklist"].restrictedToken | ascii_downcase)
      and ($root["merkle-allowlist"].token | ascii_downcase) == ($root["transfer-blocklist"].restrictedToken | ascii_downcase)
    ' <<<"$1" >/dev/null
}
