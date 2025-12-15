#!/bin/bash

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
RPC_URL=${RPC_URL:-$SEPOLIA_RPC_URL}

if [ -z "$RPC_URL" ]; then
  echo "Error: RPC_URL or SEPOLIA_RPC_URL is not set."
  echo "Please check your .env file in the project root."
  exit 1
fi

if [ -z "$DEPLOYER_MNEMONIC" ]; then
  echo "Error: DEPLOYER_MNEMONIC is not set."
  echo "Please check your .env file in the project root."
  exit 1
fi

echo "Deploying Minimal Proxy components..."

FORGE_CMD="forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast -vvvv"

if [ -n "$SEPOLIA_API_KEY" ]; then
  echo "Verifying with SEPOLIA_API_KEY..."
  FORGE_CMD="$FORGE_CMD --verify --etherscan-api-key $SEPOLIA_API_KEY"
elif [ -n "$ETHERSCAN_API_KEY" ]; then
  echo "Verifying with ETHERSCAN_API_KEY..."
  FORGE_CMD="$FORGE_CMD --verify --etherscan-api-key $ETHERSCAN_API_KEY"
fi

eval $FORGE_CMD
