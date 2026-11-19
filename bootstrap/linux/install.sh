#!/usr/bin/env bash
# Independent Ubuntu installer and read-only verification for NemoClaw/Hermes.
# No Windows, WSL, Docker Desktop, AIW native services, or session manager.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
VERSIONS="$ROOT/config/versions.json"
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
export NEMOCLAW_DISABLE_TELEMETRY=1
export NEMOCLAW_NO_EXPRESS=1
ACTION=status
ASSUME_YES=false
PASSWORD_FILE=''
UV="$HOME/.local/bin/uv"

fail() { printf '[XX] %s\n' "$*" >&2; exit 1; }
cleanup() { if [[ -n "$PASSWORD_FILE" ]]; then rm -f -- "$PASSWORD_FILE"; fi; }
trap cleanup EXIT

usage() {
    cat <<'HELP'
Usage: ./install.sh [install|verify|status|--version] [--yes] [--profile nemoclaw-podman]
  status     Read-only status of the Linux host and installed NemoClaw
  verify     Read-only checks of exact Ubuntu, rootless Podman and pinned CLI
  install    Explicit host install, preserving any existing sandbox and credentials
  --version  Offline release and Git checkout revision (branch, SHA, dirty)
No WSL/Windows operations, no implicit onboarding, rebuild or destroy.
HELP
}

while (($#)); do
    case "$1" in
        install|verify|status) ACTION="$1" ;;
        --version|version) ACTION=version ;;
        --yes|-y) ASSUME_YES=true ;;
        --profile)
            [[ $# -ge 2 && "$2" == nemoclaw-podman ]] ||
                fail 'Only --profile nemoclaw-podman is supported.'
            shift ;;
        --profile=nemoclaw-podman) ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unsupported argument: $1" ;;
    esac
    shift
done

json() {
    python3 -c 'import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
for key in sys.argv[2].split("."): d=d[key]
print(d)' "$VERSIONS" "$1"
}

version() {
    local label revision ref state=''
    label="$(json versions.project)"
    if [[ -d "$ROOT/.git" ]] && command -v git >/dev/null 2>&1; then
        revision="$(git -C "$ROOT" rev-parse --short=7 HEAD 2>/dev/null || true)"
        if [[ -n "$revision" ]]; then
            ref="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf detached)"
            [[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=normal 2>/dev/null)" ]] || state=', dirty'
            printf 'ai-workstation-linux %s (%s@%s%s)\n' "$label" "$ref" "$revision" "$state"
            return
        fi
    fi
    printf 'ai-workstation-linux %s\n' "$label"
}

preflight() {
    [[ "$(id -u)" != 0 ]] || fail 'Run as a regular Linux user, not root.'
    if [[ "$ROOT" == /mnt/* ]] && grep -Eqi 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
        fail 'Under WSL keep the Linux checkout on its ext4 filesystem, not /mnt.'
    fi
    [[ -f "$VERSIONS" ]] || fail "Missing $VERSIONS"
    [[ -r /etc/os-release ]] || fail 'Cannot read /etc/os-release'
    . /etc/os-release
    [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == "$(json versions.nemoclaw_podman.ubuntu.release)" ]] ||
        fail "Requires Ubuntu $(json versions.nemoclaw_podman.ubuntu.release) (current: ${ID:-?} ${VERSION_ID:-?})."
    [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" == systemd ]] ||
        fail 'systemd must be PID 1.'
}

check_receipt() {
    local receipt="$HOME/.config/ai-workstation/nemoclaw-installer-ref"
    local source_dir="$HOME/.local/share/aiw-nemoclaw/source"
    local binary="$HOME/.local/bin/nemohermes" pinned
    pinned="$(json versions.nemoclaw_podman.nemoclaw.commit)"
    [[ -x "$binary" ]] || fail 'NemoClaw CLI missing; installation is separate from status.'
    [[ -f "$receipt" ]] || fail 'NemoClaw install revision receipt missing; refusing silent adoption.'
    [[ "$(tr -d '\r\n' < "$receipt")" == "$pinned" ]] ||
        fail 'Installed NemoClaw receipt differs from reviewed vendor pin; no implicit update.'
    [[ -d "$source_dir/.git" ]] || fail 'NemoClaw source checkout missing.'
    [[ "$(git -C "$source_dir" rev-parse HEAD)" == "$pinned" ]] ||
        fail 'NemoClaw source checkout differs from reviewed vendor pin.'
    "$binary" --version
}

verify() {
    preflight
    command -v python3 >/dev/null || fail 'Python3 missing'
    command -v podman >/dev/null || fail 'Podman missing'
    local v socket runtime_file
    v="$(dpkg-query -W -f='${Version}' podman 2>/dev/null)" ||
        fail 'Cannot determine installed Podman package.'
    [[ "$v" == "$(json versions.nemoclaw_podman.podman.apt_package_version)" ]] ||
        fail "Podman version differs from pin ($v)."
    socket="/run/user/$(id -u)/podman/podman.sock"
    [[ -S "$socket" && -O "$socket" ]] || fail 'Current-user Podman socket missing or not owned.'
    systemctl --user is-active --quiet podman.socket ||
        fail 'Current-user podman.socket is inactive.'
    runtime_file="$(mktemp)"
    trap 'rm -f -- "$runtime_file"; cleanup' EXIT
    podman --remote --url "unix://$socket" info --format json > "$runtime_file" ||
        fail 'Current-user Podman API unavailable.'
    python3 - "$runtime_file" <<'PY'
import json,sys
host=json.load(open(sys.argv[1],encoding="utf-8"))["host"]
assert host["security"]["rootless"] is True, "Podman is not rootless"
assert host["cgroupVersion"] == "v2", "cgroups v2 required"
assert host["networkBackend"] == "netavark", "Netavark required"
PY
    rm -f -- "$runtime_file"
    trap cleanup EXIT
    check_receipt
    printf '[OK] Independent Ubuntu/Podman/NemoClaw verification passed.\n'
}

install_uv() {
    local expected installer current
    expected="$(json versions.uv)"
    current="$("$UV" --version 2>/dev/null | awk '$1=="uv"{print $2}' || true)"
    [[ "$current" == "$expected" ]] && return
    [[ ! -x "$UV" ]] || fail "Installed uv $current differs from Linux pin $expected; manual review required."
    command -v curl >/dev/null || fail 'curl missing'
    installer="$(mktemp)"
    if ! curl --proto '=https' --tlsv1.2 -fsSL "https://astral.sh/uv/$expected/install.sh" -o "$installer"; then
        rm -f -- "$installer"; fail 'Unable to fetch the reviewed uv version.'
    fi
    if ! env UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh "$installer"; then
        rm -f -- "$installer"; fail 'uv installer failed.'
    fi
    rm -f -- "$installer"
    # uv --version can include a build hash/date after the numeric version.
    # Use the same numeric parsing as the pre-install pin check.
    current="$("$UV" --version 2>/dev/null | awk '$1=="uv"{print $2; exit}' || true)"
    [[ "$current" == "$expected" ]] ||
        fail "Unexpected installed uv version (expected $expected, found ${current:-unreadable})."
}

install_linux() {
    preflight
    if [[ "$ASSUME_YES" != true ]]; then
        printf 'Install signed Ubuntu packages, pinned uv/Ansible and pinned NemoClaw CLI? Existing sandboxes will NOT be rebuilt. [y/N] '
        read -r confirm || exit 1
        [[ "$confirm" == y || "$confirm" == yes ]] || fail 'Cancelled.'
    fi
    command -v sudo >/dev/null || fail 'sudo missing'
    sudo -v
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sudo ca-certificates curl git python3 python3-apt python3-venv
    [[ -x /usr/bin/sudo.ws ]] || fail 'Ubuntu classic sudo.ws required for pinned Ansible.'
    install_uv
    "$UV" python install 3.12
    (cd "$ROOT"; "$UV" lock --check --python 3.12; "$UV" sync --frozen --python 3.12)
    export ANSIBLE_CONFIG="$ROOT/ansible/ansible.cfg"
    export ANSIBLE_INVENTORY="$ROOT/ansible/inventory/localhost.yml"
    export ANSIBLE_ROLES_PATH="$ROOT/ansible/roles"
    export AIW_USER="$(id -un)"
    export AIW_PRIMARY_GROUP="$(id -gn)"
    export AIW_HOME="$HOME"
    export AIW_REPOSITORY_ROOT="$ROOT"
    export ANSIBLE_SUDO_EXE=/usr/bin/sudo.ws
    umask 077
    PASSWORD_FILE="$(mktemp)"
    chmod 600 "$PASSWORD_FILE"
    local password
    read -r -s -p 'Linux sudo password (Ansible preflight): ' password
    printf '\n'
    printf '%s\n' "$password" > "$PASSWORD_FILE"
    unset password
    if ! sudo -S -v < "$PASSWORD_FILE"; then fail 'sudo authentication failed.'; fi
    (cd "$ROOT"; "$UV" run --frozen ansible-playbook --become-password-file "$PASSWORD_FILE" ansible/playbooks/nemoclaw-become-preflight.yml)
    (cd "$ROOT"; "$UV" run --frozen ansible-playbook --become-password-file "$PASSWORD_FILE" ansible/playbooks/nemoclaw.yml)
    (cd "$ROOT"; "$UV" run --frozen ansible-playbook --become-password-file "$PASSWORD_FILE" ansible/playbooks/nemoclaw-verify.yml)
    printf '[OK] Linux host installed; NemoClaw onboarding remains an explicit operator action.\n'
}

case "$ACTION" in
    version) version ;;
    status) version; bash "$ROOT/bin/aiw-nemo" status ;;
    verify) verify ;;
    install) install_linux ;;
esac
