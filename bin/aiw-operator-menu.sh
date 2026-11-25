#!/usr/bin/env bash
# Human-facing AIW operator; authoritative lifecycle and data stay with NemoClaw.
# Sourced by aiw-nemo (not a separate CLI or sandbox registry).
#
# The native Podman loopback alias is a VENDOR REQUIREMENT, not a new AIW
# addressing scheme. See NVIDIA/NemoClaw podman-runtime-surfaces.ts and
# https://github.com/SomeSunlight/ai-workstation-linux/issues/3
AIW_GATEWAY_SERVICE=nemoclaw-openshell-gateway.service
AIW_PODMAN_HOST_IP=169.254.2.2
AIW_PODMAN_HOST_CIDR=169.254.2.2/32

# Node emits the same known SQLite ExperimentalWarning on every NemoClaw call.
# Hide only this warning *category* for these child processes; retain all other
# warnings, stderr, errors, and the parent's NODE_OPTIONS.
vendor_hermes() {
    local options="${NODE_OPTIONS:-}"
    NODE_OPTIONS="${options:+$options }--disable-warning=ExperimentalWarning" \
        command nemohermes "$@" || return $?
    if [[ "${1:-}" == onboard ]]; then
    cat <<'EOF'

If you enabled WhatsApp, complete pairing BEFORE starting a Hermes chat:
  1. AIW -> My Hermes sandboxes -> select the new sandbox -> Open shell inside sandbox.
  2. Inside that sandbox (not WSL and not the Hermes chat), run: hermes whatsapp
  3. Keep the existing allowlist; scan the QR in WhatsApp -> Linked devices.
  4. Exit the sandbox shell and check: nemohermes NAME channels status --channel whatsapp
     Replace NAME with your sandbox name. If a restart is needed, use the
     supported NemoClaw-managed gateway procedure, not hermes gateway stop/run.
EOF

    fi
}

gateway_address_state() {
    local addresses
    command -v ip >/dev/null 2>&1 || return 3
    addresses="$(ip -o -4 address show 2>/dev/null)" || return 3
    if ! grep -Eq '(^|[[:space:]])inet[[:space:]]+169\.254\.2\.2/' <<< "$addresses"; then
        return 1
    fi
    if [[ "$(grep -Ec '^[0-9]+:[[:space:]]+lo[[:space:]]+inet[[:space:]]+169\.254\.2\.2/32([[:space:]]|$)' <<< "$addresses")" == 1 ]] &&
       [[ "$(grep -Ec '(^|[[:space:]])inet[[:space:]]+169\.254\.2\.2/' <<< "$addresses")" == 1 ]]; then
        return 0
    fi
    return 2
}

gateway_address_summary() {
    local result=0
    gateway_address_state || result=$?
    case "$result" in
        0) printf 'ready (169.254.2.2/32 on lo)' ;;
        1) printf 'MISSING after host startup' ;;
        2) printf 'CONFLICTING address assignment' ;;
        *) printf 'unknown (ip command failed)' ;;
    esac
}

gateway_summary() {
    local active='inactive' socket='missing'
    systemctl --user is-active --quiet "$AIW_GATEWAY_SERVICE" 2>/dev/null && active='active'
    [[ -S "/run/user/$(id -u)/podman/podman.sock" ]] && socket='available'
    printf 'Shared OpenShell gateway: %s | Podman socket: %s\n' "$active" "$socket"
    printf 'Sandbox-to-host route: %s\n' "$(gateway_address_summary)"
}

# A normal read-only overview never changes the host. If the address vanished
# after Windows reboot, interactive startup offers one explicit, narrow repair.
gateway_prepare_address() {
    local result=0 answer
    gateway_address_state || result=$?
    case "$result" in
        0) printf '[OK] Native Podman host address is already configured.\n'; return 0 ;;
        1) ;;
        2) printf '[BLOCKED] 169.254.2.2 is assigned incorrectly; no automated change.\n' >&2; return 1 ;;
        *) printf '[BLOCKED] Cannot inspect Linux host addresses.\n' >&2; return 1 ;;
    esac
    printf 'After a Windows reboot, the NVIDIA Podman gateway alias is missing.\n'
    printf 'This prevents sandbox policy fetch and may leave a sandbox in OpenShell Error.\n'
    printf 'NVIDIA initializes it with: sudo ip address replace %s dev lo\n' "$AIW_PODMAN_HOST_CIDR"
    if [[ ! -t 0 ]]; then
        printf '[BLOCKED] Interactive approval required. In AIW choose Gateway -> Prepare host address.\n' >&2
        return 1
    fi
    read -r -p 'Restore that exact host address now (sudo required)? [y/N] ' answer || return 1
    [[ "$answer" == y || "$answer" == Y || "$answer" == yes ]] || {
        printf 'Cancelled: no changes made.\n'
        return 1
    }
    command -v sudo >/dev/null 2>&1 || {
        printf '[BLOCKED] sudo not available.\n' >&2
        return 1
    }
    sudo -- ip address replace "$AIW_PODMAN_HOST_CIDR" dev lo || {
        printf '[BLOCKED] NVIDIA gateway address could not be established.\n' >&2
        return 1
    }
    if ! gateway_address_state; then
        printf '[BLOCKED] Gateway address was not verified after preparation.\n' >&2
        return 1
    fi
    printf '[OK] Native Podman host address restored and verified.\n'
}

# This guard is deliberately shared by both menu and direct 'aiw hermes ...'.
# Never let a missing host prerequisite turn a stopped sandbox into Error.
gateway_start_guard() {
    # NemoClaw itself validates its Podman socket; this narrow guard only
    # covers the host address absent from its existing-sandbox start path.
    gateway_prepare_address || return 1
    if ! systemctl --user is-active --quiet "$AIW_GATEWAY_SERVICE"; then
        printf '[BLOCKED] Shared OpenShell gateway is not active.\n' >&2
        printf 'Choose AIW -> Gateway -> Start shared gateway first.\n' >&2
        return 1
    fi
}

sandbox_phase() {
    local payload
    payload="$(vendor_hermes "$1" status --json 2>/dev/null)" || :
    [[ -n "$payload" ]] || return 1
    printf '%s\n' "$payload" | python3 -c '
import json, sys
try:
    data=json.load(sys.stdin)
    if data.get("schemaVersion") != 1 or not isinstance(data.get("phase"), str):
        raise ValueError("unrecognized status")
    print(data["phase"])
except (ValueError, TypeError, json.JSONDecodeError):
    sys.exit(1)
'
}

# Unknown/ambiguous phases are blocked for start/launch/resume. Do not make a
# second OpenShell lifecycle controller or attempt Error recovery as a side effect.
sandbox_action_guard() {
    local action="$1" sandbox="$2" phase
    case "$action" in
        launch|resume|start|connect|recover) ;;
        *) return 0 ;;
    esac
    if ! phase="$(sandbox_phase "$sandbox")"; then
        printf '[BLOCKED] Could not verify the sandbox phase; no lifecycle action taken.\n' >&2
        return 1
    fi
    case "$phase" in
        Error|Failed)
            printf '[BLOCKED] %s is in OpenShell %s. Repeated start/recover cannot fix it.\n' "$sandbox" "$phase" >&2
            printf 'Inspect vendor logs; no automatic destruction or recreation.\n' >&2
            return 1 ;;
    esac
    case "$action:$phase" in
        start:Stopped|launch:Ready|resume:Ready|connect:Ready|recover:Ready)
            gateway_start_guard ;;
        *)
            printf '[BLOCKED] %s is %s. Choose an action appropriate to that state.\n' "$sandbox" "$phase" >&2
            return 1 ;;
    esac
}

# Explicit shared-gateway operations never start/stop sandboxes or call onboard.
gateway_action() {
    local action="$1" reply
    case "$action" in
        status) gateway_summary ;;
        prepare) gateway_prepare_address ;;
        start)
            check_runtime || return 1
            gateway_prepare_address || return 1
            systemctl --user start "$AIW_GATEWAY_SERVICE" &&
                systemctl --user is-active "$AIW_GATEWAY_SERVICE" ;;
        stop)
            printf 'The gateway is SHARED by every sandbox; stopping it interrupts all agents.\n'
            [[ -t 0 ]] || { printf '[BLOCKED] Interactive confirmation required.\n' >&2; return 1; }
            read -r -p 'Type STOP to stop the shared gateway: ' reply || return 1
            [[ "$reply" == STOP ]] || { printf 'Cancelled.\n'; return 1; }
            systemctl --user stop "$AIW_GATEWAY_SERVICE" ;;
        *) printf 'Usage: aiw gateway [status|prepare|start|stop]\n' >&2; return 2 ;;
    esac
}

gateway_menu() {
    local choice
    while true; do
        printf '\n--- Shared gateway (all sandboxes) ---\n'
        gateway_summary
        printf ' 1) Prepare/restore NVIDIA host address (explicit sudo)\n'
        printf ' 2) Start shared OpenShell gateway\n'
        printf ' 3) Stop shared OpenShell gateway (interrupts all sandboxes)\n'
        printf ' 0) Back\n'
        read -r -p 'Selection: ' choice || return
        case "$choice" in
            1) gateway_action prepare || : ;;
            2) gateway_action start || : ;;
            3) gateway_action stop || : ;;
            0|'') return ;;
            *) printf 'No action taken.\n' ;;
        esac
    done
}

hermes_sessions() {
    local sandbox="$1" choice session
    printf 'These are Hermes conversations, not OpenShell sandboxes.\n'
    vendor_hermes "$sandbox" sessions list || return 1
    [[ -t 0 && -t 1 ]] || {
        printf 'Use a real interactive Linux terminal to resume a session.\n'
        return 1
    }
    read -r -p 'Session ID/title to resume (Enter cancels): ' session || return 1
    [[ -n "$session" ]] || return 0
    sandbox_action_guard resume "$sandbox" || return 1
    vendor_hermes "$sandbox" exec --tty --stdin -- hermes --resume "$session"
}

# Generic sandbox readiness gate for user-requested agent actions. This is
# only a menu convenience: the existing vendor lifecycle stays authoritative.
# No global "last used sandbox" record, background service, or implicit rebuild.
operator_offer_sandbox_start() {
    local sandbox="$1" purpose="$2" phase answer after
    if ! phase="$(sandbox_phase "$sandbox")"; then
        printf '[BLOCKED] Cannot determine %s phase; no sandbox action taken.\n' "$sandbox" >&2
        return 1
    fi
    case "$phase" in
        Ready) return 0 ;;
        Stopped)
            printf '\nSandbox %s is stopped. Its files and agent conversations are preserved.\n' "$sandbox"
            printf 'Start this sandbox before %s? [y/N] ' "$purpose"
            if ! IFS= read -r answer; then
                printf '\nCancelled. Sandbox remains stopped.\n'
                return 1
            fi
            case "$answer" in
                y|Y|yes|YES) ;;
                *) printf 'Cancelled. Sandbox remains stopped.\n'; return 1 ;;
            esac
            # Existing AIW start path checks the exact NVIDIA host alias,
            # offers any sudo repair openly, then delegates to NemoClaw.
            hermes_action start "$sandbox" || return 1
            if ! after="$(sandbox_phase "$sandbox")"; then
                printf '[BLOCKED] Could not verify sandbox readiness after start.\n' >&2
                return 1
            fi
            if [[ "$after" != Ready ]]; then
                printf '[BLOCKED] Sandbox startup returned phase %s, not Ready.\n' "$after" >&2
                return 1
            fi
            printf '[OK] Sandbox %s is Ready; continuing with requested action.\n' "$sandbox"
            ;;
        Error|Failed)
            printf '[BLOCKED] %s is in OpenShell %s; no restart or recovery attempted.\n' "$sandbox" "$phase" >&2
            return 1 ;;
        *)
            printf '[BLOCKED] %s has phase %s; no implicit start attempted.\n' "$sandbox" "$phase" >&2
            return 1 ;;
    esac
}

operator_sandbox_menu() {
    local choice sandbox
    select_registered_sandbox || return 0
    sandbox="$SELECTED_SANDBOX"
    while true; do
        printf '\n--- Hermes sandbox: %s ---\n' "$sandbox"
        compact_sandbox_status "$sandbox" || printf '  Phase not verified.\n'
        printf ' 1) New Hermes conversation (does not create a sandbox)\n'
        printf ' 2) Continue most recent conversation (offers to start if stopped)\n'
        printf ' 3) List/resume another conversation\n'
        printf ' 4) Start stopped sandbox (no conversation)\n'
        printf ' 5) Stop sandbox (preserve files and sessions)\n'
        printf ' 6) Open shell inside sandbox\n'
        printf ' 7) Full upstream sandbox status\n'
        printf ' 8) Advanced: gateway/forward recovery (manual)\n'
        printf ' 0) Back to sandbox list\n'
        read -r -p 'Action: ' choice || return
        case "$choice" in
            1) if operator_offer_sandbox_start "$sandbox" "starting a new Hermes conversation"; then
                   hermes_action launch "$sandbox" || printf 'Launch failed; see vendor diagnostics.\n' >&2
               fi ;;
            2) if operator_offer_sandbox_start "$sandbox" "continuing the most recent Hermes conversation"; then
                   hermes_action resume "$sandbox" || printf 'Resume failed; previous sessions have not been deleted.\n' >&2
               fi ;;
            3) if operator_offer_sandbox_start "$sandbox" "listing Hermes conversations"; then
                   hermes_sessions "$sandbox" || printf 'Session operation failed.\n' >&2
               fi ;;
            4) hermes_action start "$sandbox" || : ;;
            5) hermes_action stop "$sandbox" || : ;;
            6) if operator_offer_sandbox_start "$sandbox" "opening its shell"; then
                   connect "$sandbox" || printf 'Sandbox shell unavailable.\n' >&2
               fi ;;
            7) hermes_action status "$sandbox" || : ;;
            8)
                printf 'Recovery only after diagnosis; never use it for a sandbox in Error.\n'
                hermes_action recover "$sandbox" || : ;;
            0|'') return ;;
            *) printf 'Unknown action. No changes made.\n' ;;
        esac
    done
}

operator_onboard() {
    local aiw_onboard_interactive=1
    onboard "$@"
}

operator_advanced_menu() {
    local choice
    while true; do
        printf '\n--- Advanced / diagnostics ---\n'
        printf ' 1) Full Linux / Podman / NemoClaw status\n'
        printf ' 2) Verify host installation (read-only)\n'
        printf ' 3) Network inventory (read-only; no sandbox started)\n'
        printf ' 4) Official NemoClaw help\n'
        printf ' 5) Resume interrupted onboarding (not a chat session)\n'
        printf ' 0) Back\n'
        read -r -p 'Selection: ' choice || return
        case "$choice" in
            1) status ;;
            2) "$ROOT/install.sh" verify --profile nemoclaw-podman || : ;;
            3) network_check || : ;;
            4) vendor_hermes --help || : ;;
            5) operator_onboard --resume || : ;;
            0|'') return ;;
            *) printf 'No action taken.\n' ;;
        esac
    done
}

operator_menu() {
    local choice
    while true; do
        printf '\n🐧  AIW Linux — Hermes sandboxes\n'
        show_version
        gateway_summary
        printf ' 1) My Hermes sandboxes (chat / resume / start / stop)\n'
        printf ' 2) Create another Hermes sandbox (NemoClaw wizard)\n'
        printf ' 3) Shared gateway / post-reboot host preparation\n'
        printf ' 4) Advanced / diagnostics\n'
        printf ' q) Exit AIW (remain in Linux shell)\n'
        read -r -p 'Selection: ' choice || return
        case "$choice" in
            1) operator_sandbox_menu ;;
            2) operator_onboard || printf 'Onboarding stopped; no automatic rebuild.\n' >&2 ;;
            3) gateway_menu ;;
            4) operator_advanced_menu ;;
            q|Q) return ;;
            '') printf 'Enter cancelled; still in AIW. Use q to exit.\n' ;;
            *) printf 'Choose a displayed option.\n' ;;
        esac
    done
}
