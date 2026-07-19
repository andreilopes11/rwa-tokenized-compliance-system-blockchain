#!/usr/bin/env bash
set -euo pipefail

# Deploy TREX suite to Sepolia and write deployments/11155111.{json,backend.env}
# Fill config/sepolia.json (RPC + five agent keys) before running. Never commit real keys.

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv "config/sepolia.json"

require_cmd forge
require_cmd cast
require_cmd node

export CHAIN_ID="${CHAIN_ID:-11155111}"
export LOCAL_CHAIN_ID="$CHAIN_ID"
export SEPOLIA_RPC_URL="${SEPOLIA_RPC_URL:-${RPC_URL:-}}"
export RPC_URL="${SEPOLIA_RPC_URL}"

[ -n "$SEPOLIA_RPC_URL" ] || fail "set sepoliaRpcUrl / rpcUrl in config/sepolia.json"
[ -n "${PRIVATE_KEY:-}" ] || fail "set privateKey (deployer) in config/sepolia.json"
[ -n "${GOVERNANCE_AGENT_PRIVATE_KEY:-}" ] || fail "set governanceAgentPrivateKey in config/sepolia.json"
[ -n "${COMPLIANCE_AGENT_PRIVATE_KEY:-}" ] || fail "set complianceAgentPrivateKey in config/sepolia.json"
[ -n "${LIFECYCLE_AGENT_PRIVATE_KEY:-}" ] || fail "set lifecycleAgentPrivateKey in config/sepolia.json"
[ -n "${TRANSFER_MANAGER_AGENT_PRIVATE_KEY:-}" ] || fail "set transferManagerAgentPrivateKey in config/sepolia.json"

if [[ "$SEPOLIA_RPC_URL" == *"YOUR_API_KEY"* ]]; then
    fail "replace YOUR_API_KEY in config/sepolia.json with a real Alchemy/Infura Sepolia RPC URL"
fi

cd "$ROOT_DIR"
mkdir -p deployments

log "deploying TREX to Sepolia (chain $CHAIN_ID)"
forge script script/deploy/DeployTREX.s.sol:DeployTREX \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast

[ -f "$ROOT_DIR/deployments/$CHAIN_ID.json" ] || fail "expected deployments/$CHAIN_ID.json after DeployTREX"

export ADMIN_PRIVATE_KEY="${ADMIN_PRIVATE_KEY:-$PRIVATE_KEY}"
run_node "$(to_node_fs_path "$ROOT_DIR/scripts/write-backend-env.mjs")"

log "Sepolia deploy complete"
log "JSON: deployments/$CHAIN_ID.json"
log "Backend env: deployments/$CHAIN_ID.backend.env"
log "Copy addresses into EB + Vercel env (see DEPLOY-SEPOLIA.md)"
