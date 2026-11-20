#!/usr/bin/env bash
# Public entrypoint, independent of Windows / WSL tooling.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$ROOT/bootstrap/linux/install.sh" "$@"
