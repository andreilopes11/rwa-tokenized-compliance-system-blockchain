#!/usr/bin/env bash
set -euo pipefail

# Legacy MVP DeployCore on Sepolia (non-production). Prefer deploy-sepolia.sh (TREX).

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv "config/sepolia.json"

require_cmd forge
require_cmd node

export CHAIN_ID="${CHAIN_ID:-11155111}"
export SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-${RPC_URL:-}}"
export RPC_URL="${SEPOLIA_RPC_URL}"

[ -n "$SEPOLIA_RPC_URL" ] || fail "set sepoliaRpcUrl in config/sepolia.json"
[ -n "${PRIVATE_KEY:-}" ] || fail "set privateKey in config/sepolia.json"

cd "$ROOT_DIR"
mkdir -p deployments

log "deploying legacy MVP core to Sepolia"
forge script script/deploy/DeployCore.s.sol:DeployCore \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --verify

export ADMIN_PRIVATE_KEY="${ADMIN_PRIVATE_KEY:-$PRIVATE_KEY}"
run_node "$(to_node_fs_path "$ROOT_DIR/scripts/write-backend-env.mjs")"

log "legacy Sepolia deploy complete — deployments/$CHAIN_ID.json"
