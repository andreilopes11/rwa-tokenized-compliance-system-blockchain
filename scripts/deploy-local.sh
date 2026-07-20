#!/usr/bin/env bash
set -euo pipefail

# Deploy the production TREX suite to the local Anvil chain — parity with Sepolia
# (same DeployTREX.s.sol, same separate SoD agent keys). Legacy MVP contracts remain
# in src/legacy/ for migration testing only (see scripts/deploy-sepolia-legacy.sh).

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv
resolve_local_runtime

require_cmd node
require_cmd forge
require_cmd cast

cd "$ROOT_DIR"

if ! wait_for_rpc "$LOCAL_RPC_URL" 5; then
    fail "local RPC unavailable at $LOCAL_RPC_URL"
fi

remote_chain_id="$(cast chain-id --rpc-url "$LOCAL_RPC_URL")"
if [ "$remote_chain_id" != "$LOCAL_CHAIN_ID" ]; then
    fail "unexpected chain id at $LOCAL_RPC_URL: expected $LOCAL_CHAIN_ID, got $remote_chain_id"
fi

# Separate SoD agent keys come from config/local.json (DeployTREX rejects overlaps).
[ -n "${PRIVATE_KEY:-}" ] || fail "set privateKey (deployer / super-admin) in config/local.json"
[ -n "${GOVERNANCE_AGENT_PRIVATE_KEY:-}" ] || fail "set governanceAgentPrivateKey in config/local.json"
[ -n "${COMPLIANCE_AGENT_PRIVATE_KEY:-}" ] || fail "set complianceAgentPrivateKey in config/local.json"
[ -n "${LIFECYCLE_AGENT_PRIVATE_KEY:-}" ] || fail "set lifecycleAgentPrivateKey in config/local.json"
[ -n "${TRANSFER_MANAGER_AGENT_PRIVATE_KEY:-}" ] || fail "set transferManagerAgentPrivateKey in config/local.json"

mkdir -p "$ROOT_DIR/deployments"

log "deploying TREX suite to local chain $LOCAL_CHAIN_ID (parity with Sepolia)"
export RPC_URL="$LOCAL_RPC_URL"
export CHAIN_ID="$LOCAL_CHAIN_ID"
forge script script/deploy/DeployTREX.s.sol:DeployTREX \
    --rpc-url "$LOCAL_RPC_URL" \
    --broadcast

[ -f "$ROOT_DIR/deployments/$LOCAL_CHAIN_ID.json" ] \
    || fail "expected deployments/$LOCAL_CHAIN_ID.json after DeployTREX"

export ADMIN_PRIVATE_KEY="${ADMIN_PRIVATE_KEY:-$PRIVATE_KEY}"
run_node "$(to_node_fs_path "$ROOT_DIR/scripts/write-backend-env.mjs")"

log "local TREX deployment complete"
log "JSON: deployments/$LOCAL_CHAIN_ID.json"
log "backend env file: deployments/$LOCAL_CHAIN_ID.backend.env"
