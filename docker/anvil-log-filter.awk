# Reformat anvil stdout into structured single-line log records.
# Pipe usage: anvil ... | awk -v level=INFO -v port=8545 -f anvil-log-filter.awk
#
# Levels (quiet -> verbose): WARN, INFO, DEBUG
#   WARN  -- anvil errors / warnings only
#   INFO  -- WARN + startup banner + every tx submission (hash, from, to, block)
#   DEBUG -- INFO + each RPC method call
# Default level: INFO.
#
# anvil's raw output lacks `from`/`to` for executed transactions, so on every
# tx commit we ask the running anvil for the full envelope via `cast tx --json`.
#
# anvil's tx output spans five indented lines after the method name:
#     Transaction: 0x...
#     Gas used: ...
#     Block Number: ...
#     Block Hash: 0x...
#     Block Time: "..."
# We accumulate those fields and flush a single INFO line at Block Time.

BEGIN {
  pri["WARN"] = 3
  pri["INFO"] = 2
  pri["DEBUG"] = 1
  cur = pri[toupper(level)]
  if (!cur) cur = pri["INFO"]
  if (port == "") port = "8545"
  rpc_url = "http://127.0.0.1:" port
}

# Look up sender/recipient for a tx hash by hitting the local anvil over RPC.
# Returns "from to" (to may be empty for contract creation).
function fetch_from_to(hash,   cmd, line) {
  cmd = "cast tx --json --rpc-url " rpc_url " " hash \
        " 2>/dev/null | jq -r '\"\\(.from) \\(.to // \"\")\"'"
  if ((cmd | getline line) <= 0) line = ""
  close(cmd)
  return line
}

function ts(   cmd, t) {
  cmd = "date -u +%H:%M:%S"
  cmd | getline t
  close(cmd)
  return t
}

function emit(lvl, msg) {
  if (pri[lvl] >= cur) {
    printf "%s [%s] %s\n", ts(), lvl, msg
    fflush()
  }
}

# --- accumulating tx fields ------------------------------------------------
/^[[:space:]]+Transaction:/      { tx_hash    = $2; in_tx = 1; next }
/^[[:space:]]+Contract created:/ { contract   = $3; next }
/^[[:space:]]+Block Number:/     { block      = $3; next }
# Gas used / Block Hash are intentionally ignored — too noisy for INFO.
/^[[:space:]]+Gas used:/         { next }
/^[[:space:]]+Block Hash:/       { next }
/^[[:space:]]+Block Time:/ {
  if (in_tx) {
    pair = fetch_from_to(tx_hash)
    split(pair, parts, " ")
    from_addr = parts[1]
    to_addr   = (2 in parts ? parts[2] : "")

    msg = "tx=" tx_hash " from=" from_addr
    if (contract != "")     msg = msg " contract=" contract
    else if (to_addr != "") msg = msg " to=" to_addr
    msg = msg " block=" block
    emit("INFO", msg)
  }
  in_tx = 0; tx_hash = ""; contract = ""; block = ""
  next
}

# --- single RPC method line -----------------------------------------------
/^eth_/ || /^anvil_/ || /^net_/ || /^web3_/ || /^debug_/ || /^trace_/ || /^txpool_/ {
  emit("DEBUG", "method=" $0)
  next
}

# --- the single startup line we care about ---------------------------------
/^Listening on/ { emit("INFO", $0); next }

# --- anvil startup banner: keys (Chain ID/Base Fee/Gas Limit/Genesis ...)
#     and their numeric value lines all go to DEBUG so INFO stays quiet.
/^Chain ID$/ || /^Base Fee$/ || /^Gas Limit$/ ||
  /^Genesis Timestamp$/ || /^Genesis Number$/ || /^Block Time:/ {
  emit("DEBUG", "banner: " $0)
  next
}
# Bare numeric value line that follows the keys above.
/^[0-9]+$/ { emit("DEBUG", "banner_value: " $0); next }

# --- errors / warnings -----------------------------------------------------
/^[Ee]rror/ || /^[Ww]arning/ || /panic/ { emit("WARN", $0); next }

# --- noise: ascii-art logo, version banner, default-account dump, blanks ---
/^$/                                          { next }
/^=+$/ || /^-+$/                              { next }
/^[[:space:]]+/                               { next }   # any indented line
/^Available Accounts/ || /^Private Keys/ ||
  /^Wallet/ || /^Mnemonic:/ || /^Derivation path:/ ||
  /^\([0-9]+\) /                              { next }
# anvil version / homepage line (only emitted at boot).
/foundry-rs|github\.com\/foundry/             { emit("DEBUG", $0); next }

# --- default passthrough ---------------------------------------------------
{ emit("INFO", $0) }
