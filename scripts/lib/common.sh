#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_RPC_URL="http://127.0.0.1:8545"
DEFAULT_CHAIN_ID="31337"
DEFAULT_ANVIL_HOST="127.0.0.1"
DEFAULT_ANVIL_PORT="8545"
DEFAULT_LOCAL_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

LOCAL_STATE_DIR="$ROOT_DIR/.local"
ANVIL_PID_FILE="$LOCAL_STATE_DIR/anvil.pid"
ANVIL_LOG_FILE="$LOCAL_STATE_DIR/anvil.log"

log() {
    printf '[local-run] %s\n' "$*"
}

fail() {
    printf '[local-run] %s\n' "$*" >&2
    exit 1
}

ensure_foundry_path() {
    if [ -d "$HOME/.foundry/bin" ]; then
        export PATH="$HOME/.foundry/bin:$PATH"
    fi
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"
}

load_dotenv() {
    local dotenv_path="$ROOT_DIR/.env"
    local sanitized_dotenv
    if [ -f "$dotenv_path" ]; then
        sanitized_dotenv="$(mktemp)"
        sed 's/\r$//' "$dotenv_path" > "$sanitized_dotenv"
        set -a
        # shellcheck disable=SC1090
        . "$sanitized_dotenv"
        set +a
        rm -f "$sanitized_dotenv"
    fi
}

ensure_local_state_dir() {
    mkdir -p "$LOCAL_STATE_DIR"
}

stop_managed_anvil() {
    ensure_local_state_dir

    if [ ! -f "$ANVIL_PID_FILE" ]; then
        return 0
    fi

    anvil_pid="$(cat "$ANVIL_PID_FILE")"
    if kill -0 "$anvil_pid" >/dev/null 2>&1; then
        kill "$anvil_pid" >/dev/null 2>&1 || true
        log "anvil stopped (pid $anvil_pid)"
    else
        log "recorded pid is no longer running"
    fi

    rm -f "$ANVIL_PID_FILE"
}

clean_generated_files() {
    log "cleaning local artifacts"
    rm -rf \
        "$ROOT_DIR/cache" \
        "$ROOT_DIR/out" \
        "$ROOT_DIR/broadcast" \
        "$ROOT_DIR/deployments"

    rm -f \
        "$LOCAL_STATE_DIR/anvil.log" \
        "$LOCAL_STATE_DIR/anvil.pid"
}

artifact_bytecode() {
    local artifact_path="$1"
    node -e 'const fs=require("fs"); const artifact=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(artifact.bytecode.object);' "$artifact_path"
}

json_field() {
    local json_payload="$1"
    local field_name="$2"
    node -e 'const payload=JSON.parse(process.argv[1]); const field=process.argv[2]; const value=payload[field]; if (value === undefined || value === null) process.exit(1); process.stdout.write(String(value));' "$json_payload" "$field_name"
}

wait_for_rpc() {
    local rpc_url="$1"
    local max_attempts="${2:-30}"
    local attempt

    for attempt in $(seq 1 "$max_attempts"); do
        if cast chain-id --rpc-url "$rpc_url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    return 1
}

resolve_local_runtime() {
    LOCAL_RPC_URL="${LOCAL_RPC_URL:-$DEFAULT_RPC_URL}"
    LOCAL_CHAIN_ID="${LOCAL_CHAIN_ID:-$DEFAULT_CHAIN_ID}"
    LOCAL_ANVIL_HOST="${LOCAL_ANVIL_HOST:-$DEFAULT_ANVIL_HOST}"
    LOCAL_ANVIL_PORT="${LOCAL_ANVIL_PORT:-$DEFAULT_ANVIL_PORT}"
    LOCAL_DEPLOY_PRIVATE_KEY="${LOCAL_PRIVATE_KEY:-$DEFAULT_LOCAL_PRIVATE_KEY}"
}
