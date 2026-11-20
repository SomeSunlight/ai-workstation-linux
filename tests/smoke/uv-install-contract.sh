#!/usr/bin/env bash
# Offline regression for the pinned uv installation/version-check contract.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME/.local/bin"
UV="$HOME/.local/bin/uv"
json() {
    [[ "$1" == versions.uv ]] || return 1
    printf '0.11.26\n'
}
fail() { printf '[XX] %s\n' "$*" >&2; exit 1; }
# Extract the real production function rather than duplicating its parser.
source <(sed -n '/^install_uv() {$/,/^}$/p' "$ROOT/bootstrap/linux/install.sh")
declare -F install_uv >/dev/null
curl() {
    local out=''
    while (( $# )); do
        if [[ "$1" == -o ]]; then out="$2"; shift 2; else shift; fi
    done
    [[ -n "$out" ]] || fail 'mock curl had no -o destination'
    printf 'called\n' >> "$tmp/curl-calls"
    cat > "$out" <<'INSTALLER'
#!/bin/sh
set -eu
mkdir -p "$UV_INSTALL_DIR"
cat > "$UV_INSTALL_DIR/uv" <<'UV'
#!/bin/sh
printf 'uv 0.11.26 (mock-build-hash 2026-11-19)\n'
UV
chmod +x "$UV_INSTALL_DIR/uv"
INSTALLER
}
# A fresh install must accept a numeric pin plus optional build metadata.
install_uv
[[ -x "$UV" && "$(wc -l < "$tmp/curl-calls")" == 1 ]]
# A second run must be idempotent, without another download.
install_uv
[[ "$(wc -l < "$tmp/curl-calls")" == 1 ]]
# A different installed version must fail closed, without replacement.
cat > "$UV" <<'MISMATCH'
#!/bin/sh
printf 'uv 0.11.27 (other-build)\n'
MISMATCH
chmod +x "$UV"
if (install_uv) 2> "$tmp/error"; then
    fail 'mismatched installed uv was incorrectly accepted'
fi
grep -q 'differs from Linux pin 0.11.26' "$tmp/error"
[[ "$(wc -l < "$tmp/curl-calls")" == 1 ]]
printf '[OK] uv pin: fresh install, metadata, idempotence, mismatch refusal.\n'
