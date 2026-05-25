# syntax=docker/dockerfile:1.7
#
# Solidity Tutorial — anvil + auto-deploy image.
#
# Boots anvil on 0.0.0.0:8545 (deterministic mnemonic, chainId 31337) and
# runs every q-XX/script/Deploy.s.sol on startup. Deployed addresses are
# written to /shared/addresses.json for a web UI / instructor to consume.

FROM ghcr.io/foundry-rs/foundry:latest

USER root

# Alpine-based image: install bash + jq for the entrypoint script.
# Fallback to apt-get if the base image ever switches to debian.
RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash jq curl; \
    else \
      apt-get update && apt-get install -y --no-install-recommends bash jq curl && rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /app

# Copy the full repo; .dockerignore strips node_modules/, out/, cache/,
# broadcast/, .git/, agent state, etc.
COPY . .

# Pre-compile every challenge so container startup only has to send
# broadcast transactions — no fresh solc run per boot.
RUN bash -c 'set -e; for d in q-*/; do echo "[build] forge build in $d"; (cd "$d" && forge build); done'

RUN chmod +x /app/docker/entrypoint.sh

EXPOSE 8545

ENTRYPOINT ["/bin/bash", "/app/docker/entrypoint.sh"]
