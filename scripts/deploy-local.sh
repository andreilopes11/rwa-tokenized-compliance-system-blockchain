#!/usr/bin/env bash
set -euo pipefail

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

log "building contracts"
forge build >/dev/null

owner_address="$(cast wallet address --private-key "$LOCAL_DEPLOY_PRIVATE_KEY")"
identity_artifact="$ROOT_DIR/out/IdentityRegistry.sol/IdentityRegistry.json"
token_artifact="$ROOT_DIR/out/PermissionedToken.sol/PermissionedToken.json"

[ -f "$identity_artifact" ] || fail "missing artifact: $identity_artifact"
[ -f "$token_artifact" ] || fail "missing artifact: $token_artifact"

registry_bytecode="$(artifact_bytecode "$identity_artifact")"
registry_constructor_args="$(cast abi-encode 'constructor(address)' "$owner_address")"

log "deploying IdentityRegistry"
registry_receipt="$(cast send --json \
    --private-key "$LOCAL_DEPLOY_PRIVATE_KEY" \
    --rpc-url "$LOCAL_RPC_URL" \
    --create "${registry_bytecode}${registry_constructor_args#0x}")"
registry_address="$(json_field "$registry_receipt" contractAddress)"

token_bytecode="$(artifact_bytecode "$token_artifact")"
token_constructor_args="$(cast abi-encode 'constructor(string,string,address,address)' \
    'Tokenized RWA Compliance Share' \
    'RWAC' \
    "$registry_address" \
    "$owner_address")"

log "deploying PermissionedToken"
token_receipt="$(cast send --json \
    --private-key "$LOCAL_DEPLOY_PRIVATE_KEY" \
    --rpc-url "$LOCAL_RPC_URL" \
    --create "${token_bytecode}${token_constructor_args#0x}")"
token_address="$(json_field "$token_receipt" contractAddress)"

resolved_owner="$(cast call "$registry_address" 'owner()(address)' --rpc-url "$LOCAL_RPC_URL")"
resolved_registry="$(cast call "$token_address" 'identityRegistry()(address)' --rpc-url "$LOCAL_RPC_URL")"

[ "$resolved_owner" = "$owner_address" ] || fail "registry owner does not match the expected deployer"
[ "${resolved_registry,,}" = "${registry_address,,}" ] || fail "token points to an unexpected registry"

mkdir -p "$ROOT_DIR/deployments"

node -e 'const fs=require("fs"); const [path, registry, token, owner] = process.argv.slice(1); fs.writeFileSync(path, JSON.stringify({ identityRegistry: registry, permissionedToken: token, owner }, null, 2) + "\n");' \
    "$ROOT_DIR/deployments/$LOCAL_CHAIN_ID.json" \
    "$registry_address" \
    "$token_address" \
    "$owner_address"

cat > "$ROOT_DIR/deployments/$LOCAL_CHAIN_ID.backend.env" <<EOF
RPC_URL=$LOCAL_RPC_URL
CHAIN_ID=$LOCAL_CHAIN_ID
IDENTITY_REGISTRY_ADDRESS=$registry_address
TOKEN_ADDRESS=$token_address
ADMIN_PRIVATE_KEY=$LOCAL_DEPLOY_PRIVATE_KEY
EOF

log "local deployment complete"
log "IdentityRegistry: $registry_address"
log "PermissionedToken: $token_address"
log "owner: $owner_address"
log "backend env file: deployments/$LOCAL_CHAIN_ID.backend.env"
