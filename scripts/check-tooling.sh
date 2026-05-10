#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv
resolve_local_runtime

require_cmd node
require_cmd npm
require_cmd forge
require_cmd cast
require_cmd anvil

log "tooling ok"
log "node $(node -v)"
log "npm $(npm -v)"
log "forge $(forge --version | head -n 1)"
log "cast $(cast --version | head -n 1)"
log "anvil $(anvil --version | head -n 1)"
