# syntax=docker/dockerfile:1
#
# anvil + pre-deployed state image (multi-stage).
#   builder — deploy every q-XX/script/Deploy.s.sol once, snapshot the state.
#   runtime — slim base with only anvil + cast + the baked /snapshot.
# Boot drops from ~30s (live deploy) to ~1s (--load-state).

# --- stage 1: builder -------------------------------------------------------
FROM ghcr.io/foundry-rs/foundry:latest AS builder

USER root

RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash jq curl; \
    else \
      apt-get update && apt-get install -y --no-install-recommends bash jq curl && rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /app

COPY . .

RUN forge soldeer install

# Pre-compile every package so the snapshot build only pays for broadcast.
RUN bash -c 'set -e; shopt -s nullglob; for f in /app/*/script/Deploy.s.sol; do \
      d=$(dirname "$(dirname "$f")"); \
      echo "[build] forge build in $(basename "$d")"; \
      (cd "$d" && forge build); \
    done'

RUN chmod +x /app/docker/entrypoint.sh /app/docker/build-snapshot.sh

# ARGs participate in the layer cache key, so changing either re-deploys + re-dumps.
ARG ANVIL_MNEMONIC="test test test test test test test test test test test junk"
ARG ANVIL_CHAIN_ID=31337
ENV ANVIL_MNEMONIC=$ANVIL_MNEMONIC
ENV ANVIL_CHAIN_ID=$ANVIL_CHAIN_ID
RUN /app/docker/build-snapshot.sh

# --- stage 2: runtime -------------------------------------------------------
# glibc base: Foundry binaries are built on ubuntu:22.04 (glibc 2.35); bookworm
# (2.36) is newer/backward-compatible. Bump to match if Foundry's base advances.
FROM debian:bookworm-slim AS runtime

# jq + awk + ca-certificates are all entrypoint.sh needs beyond the base.
# cast eagerly loads the system cert store at startup, so it errors even on
# plain-http RPC (healthcheck, log filter) without ca-certificates.
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq gawk ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/local/bin/anvil /usr/local/bin/anvil
COPY --from=builder /usr/local/bin/cast  /usr/local/bin/cast
COPY --from=builder /app/docker /app/docker
COPY --from=builder /snapshot   /snapshot

# Re-bake so standalone `docker run` matches its snapshot; compose still overrides.
ARG ANVIL_MNEMONIC="test test test test test test test test test test test junk"
ARG ANVIL_CHAIN_ID=31337
ENV ANVIL_MNEMONIC=$ANVIL_MNEMONIC
ENV ANVIL_CHAIN_ID=$ANVIL_CHAIN_ID

EXPOSE 8545

ENTRYPOINT ["/bin/bash", "/app/docker/entrypoint.sh"]
