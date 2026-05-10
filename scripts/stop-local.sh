#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_local_state_dir

if [ ! -f "$ANVIL_PID_FILE" ]; then
    log "nenhum anvil iniciado por script encontrado"
    exit 0
fi

anvil_pid="$(cat "$ANVIL_PID_FILE")"
if kill -0 "$anvil_pid" >/dev/null 2>&1; then
    kill "$anvil_pid"
    log "anvil encerrado (pid $anvil_pid)"
else
    log "pid registrado nao esta mais em execucao"
fi

rm -f "$ANVIL_PID_FILE"
