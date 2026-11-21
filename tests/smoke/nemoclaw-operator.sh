#!/usr/bin/env bash
# Offline contract for the human-facing AIW cockpit and reboot safety guard.
# No WSL, Podman socket, sudo privileges, sandbox or NVIDIA installation needed.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
smoke_step_name='initializing mock environment'
last_failed_line=''
last_failed_command=''
smoke_step() {
    smoke_step_name="$1"
    printf '\n[TEST] %s\n' "$smoke_step_name"
}
show_mock_output() {
    local file="$1"
    [[ -s "$file" ]] || { printf '  (no mock output)\n'; return 0; }
    sed 's/^/    | /' "$file"
}
smoke_exit() {
    local code="$1"
    trap - EXIT
    if (( code != 0 )); then
        printf '\n[FAIL] %s (exit %s)\n' "$smoke_step_name" "$code" >&2
        if [[ -n "$last_failed_line" ]]; then
            printf '  Failed check at test line %s: %s\n' "$last_failed_line" "$last_failed_command" >&2
        fi
        for file in "$tmp/fail" "$tmp/menu.log" "$tmp/trace"; do
            [[ -s "$file" ]] || continue
            printf '  Captured MOCK output: %s\n' "$(basename "$file")" >&2
            tail -n 35 "$file" | sed 's/^/    | /' >&2
        done
    fi
    rm -rf -- "$tmp"
}
trap 'last_failed_line=$LINENO; last_failed_command=$BASH_COMMAND' ERR
trap 'smoke_exit "$?"' EXIT
mkdir -p "$tmp/.local/bin"
trace="$tmp/trace"
: > "$trace"
printf '[INFO] Offline only: NemoClaw, ip, systemctl and sudo are replaced by mocks.\n'
printf '[INFO] This script never changes the real gateway, network or sandbox.\n'
printf '[INFO] Safety prompts are tested visibly as refused/declined; no hidden interaction.\n'

cat > "$tmp/.local/bin/nemohermes" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${NEMOCLAW_GATEWAY_RUNTIME:-}" == podman ]] || exit 96
[[ "${NODE_OPTIONS:-}" == *'--disable-warning=ExperimentalWarning'* ]] || exit 97
if [[ "${1:-}" == list && "${2:-}" == --json ]]; then
    if [[ "${FAKE_BAD_LIST:-}" == yes ]]; then
        printf 'malformed upstream JSON\n'
    else
        printf '%s\n' '{"schemaVersion":1,"defaultSandbox":"ready-hermes","sandboxes":[{"name":"ready-hermes","provider":"openrouter-api","model":"deepseek","livePhase":"Ready"},{"name":"stopped-hermes","provider":"compatible-endpoint","model":"sparringpartner","livePhase":"Stopped"},{"name":"error-hermes","provider":"openrouter-api","model":"other-model","livePhase":"Error"}]}'
    fi
    exit 0
fi
printf '%s\n' "$*" >> "$FAKE_NEMO_TRACE"
if [[ "${2:-}" == status && "${3:-}" == --json ]]; then
    case "$1" in
        ready-hermes) phase=Ready; provider=openrouter-api ;;
        stopped-hermes) phase=Stopped; provider=compatible-endpoint ;;
        error-hermes) phase=Error; provider=openrouter-api ;;
        *) phase=Unknown; provider=unknown ;;
    esac
    printf '{"schemaVersion":1,"name":"%s","phase":"%s","gatewayState":"present","provider":"%s","model":"test"}\n' "$1" "$phase" "$provider"
    [[ "${FAKE_STATUS_FAIL:-}" != yes ]] || exit 93
    exit 0
fi
[[ "${FAKE_NEMO_FAIL:-}" != yes ]] || exit 93
MOCK
chmod +x "$tmp/.local/bin/nemohermes"

cat > "$tmp/.local/bin/ip" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${FAKE_IP_DOWN:-}" == yes ]]; then exit 1; fi
printf '1: lo    inet 127.0.0.1/8 scope host lo\n'
case "${FAKE_IP_STATE:-ready}" in
    ready) printf '1: lo    inet 169.254.2.2/32 scope global lo\n' ;;
    missing) ;;
    conflict) printf '2: eth0    inet 169.254.2.2/24 scope global eth0\n' ;;
esac
MOCK
chmod +x "$tmp/.local/bin/ip"

cat > "$tmp/.local/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
    *' is-active '*) [[ "${FAKE_GATEWAY_DOWN:-}" != yes ]] ;;
    *' start '*) printf 'gateway-start\n' >> "$FAKE_NEMO_TRACE" ;;
    *' stop '*) printf 'gateway-stop\n' >> "$FAKE_NEMO_TRACE" ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$tmp/.local/bin/systemctl"

cat > "$tmp/.local/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected sudo\n' >> "$FAKE_NEMO_TRACE"
exit 99
MOCK
chmod +x "$tmp/.local/bin/sudo"

invoke() {
    HOME="$tmp" FAKE_NEMO_TRACE="$trace" bash "$ROOT/bin/aiw-nemo" "$@"
}

# Development provenance and collision-safe registration remain intact.
smoke_step "Check version and local CLI registration (mock HOME)"
invoke --version > "$tmp/version.log"
grep -Eq 'aiw-nemo 0\.1\.0 \([^)]+@[0-9a-f]{7}' "$tmp/version.log"
HOME="$tmp" bash "$ROOT/install.sh" register-cli > "$tmp/register.log"
HOME="$tmp" bash "$ROOT/install.sh" register-cli >> "$tmp/register.log"
grep -Fq 'already points to this Linux checkout' "$tmp/register.log"

# Explicit vendor-only operations require a verified phase and host route.
smoke_step "Accept valid Hermes commands with mocked Ready/Stopped phases"
invoke hermes launch ready-hermes
invoke hermes start stopped-hermes
invoke hermes stop ready-hermes
invoke hermes status ready-hermes
invoke hermes recover ready-hermes
grep -Fxq 'launch ready-hermes' "$trace"
grep -Fxq 'stopped-hermes start' "$trace"
grep -Fxq 'ready-hermes stop' "$trace"
grep -Fxq 'ready-hermes status' "$trace"
grep -Fxq 'ready-hermes recover' "$trace"

# Invalid names, unsupported destructive actions, wrong phase fail closed.
smoke_step "Refuse Error-phase, unsafe names and unsupported operations"
if invoke hermes start error-hermes > "$tmp/fail" 2>&1; then exit 1; fi
grep -q 'OpenShell Error' "$tmp/fail"
if invoke hermes start ready-hermes > "$tmp/fail" 2>&1; then exit 1; fi
if invoke hermes launch stopped-hermes > "$tmp/fail" 2>&1; then exit 1; fi
if invoke hermes launch '../unsafe' > "$tmp/fail" 2>&1; then exit 1; fi
if invoke hermes destroy ready-hermes > "$tmp/fail" 2>&1; then exit 1; fi
if invoke hermes launch > "$tmp/fail" 2>&1; then exit 1; fi
if grep -Eq '(error-hermes start|ready-hermes start|launch stopped-hermes|destroy)' "$trace"; then
    echo 'Unsafe upstream lifecycle call found in trace.' >&2; exit 1
fi

# Real Windows reboot failure: stored aliases remain, host lo assignment gone.
smoke_step "Simulate Windows-reboot host-address failure; show every refusal"
# The missing/conflicting/uninspectable address must block BEFORE vendor start.
for state in missing conflict; do
    printf '  Mock host address = %s. No interactive approval provided.\n' "$state"
    # Unlike a real AIW menu session, this automated test must never solicit
    # operator input. The guard should visibly explain its refusal instead.
    if FAKE_IP_STATE="$state" invoke hermes start stopped-hermes </dev/null > "$tmp/fail" 2>&1; then
        echo 'Missing/conflicting gateway alias unexpectedly permitted startup.' >&2; exit 1
    fi
    show_mock_output "$tmp/fail"
    grep -Eq '\[BLOCKED\]|Interactive approval required' "$tmp/fail"
done
printf '  Mock ip tool fails completely:\n'
if FAKE_IP_DOWN=yes invoke hermes launch ready-hermes </dev/null > "$tmp/fail" 2>&1; then exit 1; fi
show_mock_output "$tmp/fail"
printf '  Mock shared gateway is stopped:\n'
if FAKE_GATEWAY_DOWN=yes invoke hermes start stopped-hermes </dev/null > "$tmp/fail" 2>&1; then exit 1; fi
show_mock_output "$tmp/fail"
grep -Fq 'Shared OpenShell gateway is not active' "$tmp/fail"
if grep -Fxq 'gateway-start' "$trace"; then
    echo 'Gateway auto-started unexpectedly.' >&2; exit 1
fi
[[ "$(grep -Fxc 'stopped-hermes start' "$trace")" == 1 ]]

# Non-interactive repair, stop and conversation resume must not mutate state.
smoke_step "Simulate missing approval: show actual safety messages; never invoke real sudo"
# Every negative test explicitly has no stdin. Show the produced message
# and check that no mock ever records a privileged or destructive action.
printf '  Real interactive question: Restore that exact host address now (sudo required)? [y/N]\n'
grep -Fq "read -r -p 'Restore that exact host address now (sudo required)? [y/N] '" "$ROOT/bin/aiw-operator-menu.sh"
printf '  TEST input: no approval is supplied; expected result is refusal, not repair.\n'
if FAKE_IP_STATE=missing invoke gateway prepare </dev/null > "$tmp/fail" 2>&1; then exit 1; fi
show_mock_output "$tmp/fail"
grep -Fq 'Interactive approval required' "$tmp/fail"
printf '  Real interactive question: Type STOP to stop the shared gateway:\n'
grep -Fq "read -r -p 'Type STOP to stop the shared gateway: '" "$ROOT/bin/aiw-operator-menu.sh"
printf '  TEST input: no STOP confirmation is supplied; expected result is refusal.\n'
if invoke gateway stop </dev/null > "$tmp/fail" 2>&1; then exit 1; fi
show_mock_output "$tmp/fail"
grep -Fq 'Interactive confirmation required' "$tmp/fail"
printf '  Resume chat without an interactive terminal:\n'
if invoke hermes resume ready-hermes </dev/null > "$tmp/fail" 2>&1; then exit 1; fi
show_mock_output "$tmp/fail"
grep -Fq 'interactive terminal' "$tmp/fail"
if grep -q 'unexpected sudo' "$trace"; then exit 1; fi
if grep -q ' exec ' "$trace"; then exit 1; fi

# Short, layered menu; numbered sandbox, optional status, explicit meaning.
smoke_step "Navigate multi-sandbox menu with pre-defined MOCK answers"
printf '1\n1\n1\n0\nq\n' | invoke menu > "$tmp/menu.log"
grep -Fq 'AIW Linux — Hermes sandboxes' "$tmp/menu.log"
grep -Fq '1) My Hermes sandboxes' "$tmp/menu.log"
grep -Fq '2) Create another Hermes sandbox' "$tmp/menu.log"
grep -Fq '3) Shared gateway' "$tmp/menu.log"
grep -Fq '1) ready-hermes' "$tmp/menu.log"
grep -Fq '2) stopped-hermes' "$tmp/menu.log"
grep -Fq '3) error-hermes' "$tmp/menu.log"
grep -Fq 'New Hermes conversation' "$tmp/menu.log"
grep -Fq 'Continue most recent conversation' "$tmp/menu.log"
grep -Fq 'Exit AIW (remain in Linux shell)' "$tmp/menu.log"
grep -Fxq 'launch ready-hermes' "$trace"
if grep -q 'network_policies:' "$tmp/menu.log"; then exit 1; fi

# Stop/start is scoped to one selected sandbox; Error never gets vendor start.
smoke_step "Verify sandbox-scoped start and refusal for Error phase"
printf '1\n2\n4\n0\nq\n' | invoke menu > "$tmp/menu.log"
[[ "$(grep -Fxc 'stopped-hermes start' "$trace")" == 2 ]]
printf '1\n3\n4\n0\nq\n' | invoke menu > "$tmp/menu.log" 2>&1
printf '  Mock Error-phase attempt (no vendor start):\n'
grep -F 'OpenShell Error' "$tmp/menu.log"
if grep -Fxq 'error-hermes start' "$trace"; then exit 1; fi

# Empty, invalid and corrupt inventory choices cancel safely.
smoke_step "Cancel safely and reject invalid inventory/selection"
for input in $'1\n\nq\n' $'1\n0\nq\n' $'1\n99\nq\n'; do
    printf '%s' "$input" | invoke menu > "$tmp/menu.log" 2>&1
    grep -Fq 'AIW Linux' "$tmp/menu.log"
done
printf '1\nq\n' | FAKE_BAD_LIST=yes invoke menu > "$tmp/menu.log" 2>&1
grep -Fq 'Cannot parse upstream sandbox registry' "$tmp/menu.log"
printf '3\n0\nq\n' | invoke menu > "$tmp/menu.log"
grep -Fq 'Shared gateway (all sandboxes)' "$tmp/menu.log"

echo '[OK] AIW cockpit: multi-sandbox navigation, vendor lifecycle and reboot-safe guard.'
