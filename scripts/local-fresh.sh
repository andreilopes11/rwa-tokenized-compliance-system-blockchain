#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ensure_foundry_path
load_dotenv
resolve_local_runtime
ensure_local_state_dir

stop_managed_anvil
clean_generated_files

"$ROOT_DIR/scripts/run-local.sh"
