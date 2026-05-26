# syntax=docker/dockerfile:1
#
# Solidity Tutorial — anvil + pre-deployed state image.
#
# At build time we boot a transient anvil, run every q-XX/script/Deploy.s.sol
# once, and snapshot the resulting state via anvil_dumpState. The runtime
# entrypoint then only has to `anvil --load-state` and serve traffic —
# container boot drops from ~30s (live deploy) to ~1s (state load).
#
# ANVIL_MNEMONIC / ANVIL_CHAIN_ID are build ARGs so Docker's layer cache
# invalidates the snapshot when they change. Pass them via
# `docker compose build --build-arg ANVIL_MNEMONIC=...` or rely on the
# docker-compose.yml build.args block that forwards .env values.

FROM ghcr.io/foundry-rs/foundry:latest

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

# --- build-time deploy + state dump ----------------------------------------
# ARG values participate in the layer cache key, so changing the mnemonic or
# chain id triggers a fresh deploy + dump on the next `docker compose build`.
ARG ANVIL_MNEMONIC="test test test test test test test test test test test junk"
ARG ANVIL_CHAIN_ID=31337
ENV ANVIL_MNEMONIC=$ANVIL_MNEMONIC
ENV ANVIL_CHAIN_ID=$ANVIL_CHAIN_ID
RUN /app/docker/build-snapshot.sh

EXPOSE 8545

ENTRYPOINT ["/bin/bash", "/app/docker/entrypoint.sh"]
