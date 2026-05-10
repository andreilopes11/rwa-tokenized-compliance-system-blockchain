#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv
resolve_local_runtime
ensure_local_state_dir

started_anvil=0

cleanup_on_error() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$started_anvil" -eq 1 ] && [ -f "$ANVIL_PID_FILE" ]; then
        local anvil_pid
        anvil_pid="$(cat "$ANVIL_PID_FILE")"
        if kill -0 "$anvil_pid" >/dev/null 2>&1; then
            kill "$anvil_pid" >/dev/null 2>&1 || true
        fi
        rm -f "$ANVIL_PID_FILE"
        log "anvil stopped because bootstrap failed"
    fi
}

trap cleanup_on_error EXIT

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/check-tooling.sh"

if [ ! -d "$ROOT_DIR/node_modules/@openzeppelin/contracts" ]; then
    log "npm dependencies missing, running npm install"
    npm install
fi

log "running build"
forge build

log "running tests"
forge test -vvv

if wait_for_rpc "$LOCAL_RPC_URL" 2; then
    remote_chain_id="$(cast chain-id --rpc-url "$LOCAL_RPC_URL")"
    if [ "$remote_chain_id" != "$LOCAL_CHAIN_ID" ]; then
        fail "an RPC is already running at $LOCAL_RPC_URL with chain id $remote_chain_id"
    fi
    log "reusing existing anvil at $LOCAL_RPC_URL"
else
    if [ -f "$ANVIL_PID_FILE" ]; then
        rm -f "$ANVIL_PID_FILE"
    fi

    log "starting anvil at $LOCAL_RPC_URL"
    if command -v setsid >/dev/null 2>&1; then
        setsid anvil \
            --host "$LOCAL_ANVIL_HOST" \
            --port "$LOCAL_ANVIL_PORT" \
            --chain-id "$LOCAL_CHAIN_ID" \
            > "$ANVIL_LOG_FILE" 2>&1 < /dev/null &
    else
        nohup anvil \
            --host "$LOCAL_ANVIL_HOST" \
            --port "$LOCAL_ANVIL_PORT" \
            --chain-id "$LOCAL_CHAIN_ID" \
            > "$ANVIL_LOG_FILE" 2>&1 < /dev/null &
    fi

    echo $! > "$ANVIL_PID_FILE"
    started_anvil=1

    wait_for_rpc "$LOCAL_RPC_URL" 30 || fail "anvil did not respond at $LOCAL_RPC_URL"
fi

"$ROOT_DIR/scripts/deploy-local.sh"

log "local environment ready"
log "RPC: $LOCAL_RPC_URL"
log "deployments: $ROOT_DIR/deployments/$LOCAL_CHAIN_ID.json"
log "backend env: $ROOT_DIR/deployments/$LOCAL_CHAIN_ID.backend.env"
log "anvil log: $ANVIL_LOG_FILE"

trap - EXIT
