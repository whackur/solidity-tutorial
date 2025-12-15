#!/bin/bash

# Function to load env variables compatible with .env files
load_env() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    while IFS='=' read -r key value || [ -n "$key" ]; do
      if [[ ! "$key" =~ ^# ]] && [[ -n "$key" ]]; then
        key=$(echo "$key" | tr -d '\r')
        value=$(echo "$value" | tr -d '\r')
        export "$key"="$value"
      fi
    done < "$env_file"
  fi
}

load_env "../.env"
load_env ".env"

# Handle API Key compatibility
if [ -z "$ETHERSCAN_API_KEY" ] && [ -n "$SEPOLIA_API_KEY" ]; then
    export ETHERSCAN_API_KEY="$SEPOLIA_API_KEY"
fi

# Check which script to run (Deploy or Upgrade)
SCRIPT=${1:-Deploy} # Default to Deploy if no argument provided

# Example usage:
# ./deploy.sh           -> runs Deploy.s.sol
# ./deploy.sh Upgrade   -> runs Upgrade.s.sol (if you had one)

forge script script/${SCRIPT}.s.sol:DeployScript --rpc-url sepolia --broadcast --verify -vvvv
