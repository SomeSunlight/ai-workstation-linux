#!/usr/bin/env bash
# Offline contract test: no Ubuntu, Podman, package install, Internet or WSL needed.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"
bash -n install.sh bootstrap/linux/install.sh bin/aiw-nemo bin/aiw-operator-menu.sh
python3 -m json.tool config/versions.json >/dev/null
[[ -f uv.lock && -f pyproject.toml ]]
[[ ! -e bootstrap/windows/Launch-NemoClaw.ps1 ]]
[[ ! -e aiw.cmd ]]
[[ ! -e ansible/roles/docker_engine ]]
[[ ! -e bin/aiw-core ]]
[[ -f docs/operator.md && -f docs/nemoclaw-recovery.md ]]
! grep -q "docs/nemoclaw-operator.md" bin/aiw-nemo
# The source installer must not call monolithic AIW, WSL or a Windows service.
! grep -Eq 'bin/aiw[[:space:]]|wsl\.exe|powershell\.exe|Services\.ps1|docker-compose' bootstrap/linux/install.sh
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
for forbidden in curl sudo apt-get podman; do
    cat > "$tmp/bin/$forbidden" <<'MOCK'
#!/bin/sh
echo 'unexpected side effect' >&2
exit 77
MOCK
    chmod +x "$tmp/bin/$forbidden"
done
PATH="$tmp/bin:$PATH" ./install.sh --version >"$tmp/version"
grep -Eq '^ai-workstation-linux 0\.1\.0 \((detached|[^()]+)@[0-9a-f]{7}' "$tmp/version"
PATH="$tmp/bin:$PATH" ./install.sh --help >"$tmp/help"
grep -q 'No WSL/Windows operations' "$tmp/help"
echo '[OK] Linux CLI contract: independent, offline, correct provenance.'
