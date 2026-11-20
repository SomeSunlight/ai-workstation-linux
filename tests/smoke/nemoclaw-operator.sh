#!/usr/bin/env bash
# Offline operator-CLI dispatch regression: no WSL/Podman/NemoClaw installation.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/.local/bin"

cat > "$tmp/.local/bin/nemohermes" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${NEMOCLAW_GATEWAY_RUNTIME:-}" == podman ]] || exit 96
if [[ "${1:-}" == list ]]; then
  if [[ "${FAKE_NEMO_BAD_LIST:-}" == yes ]]; then
    printf 'malformed upstream JSON\n'
  else
    printf '%s\n' '{"schemaVersion":1,"defaultSandbox":"testhermes01","sandboxes":[{"name":"testhermes01","provider":"compatible-endpoint","model":"sparringpartner","livePhase":"Ready"},{"name":"other-hermes","provider":"openrouter-api","model":"other-model","livePhase":"Stopped"}]}'
  fi
  exit 0
fi
if [[ "${FAKE_NEMO_FAIL:-}" == yes ]]; then exit 93; fi
printf '%s\n' "$*" >> "$FAKE_NEMO_TRACE"
MOCK
chmod +x "$tmp/.local/bin/nemohermes"
trace="$tmp/trace"
touch "$trace"

invoke() {
    HOME="$tmp" FAKE_NEMO_TRACE="$trace" bash "$ROOT/bin/aiw-nemo" "$@"
}

# Offline --version identifies the Linux checkout and never calls NemoClaw.
invoke --version >"$tmp/version.log"
grep -Fq 'aiw-nemo 0.1.0 (' "$tmp/version.log"
grep -Eq '@[0-9a-f]{7}' "$tmp/version.log"

invoke hermes launch testhermes01
invoke hermes start testhermes01
invoke hermes status testhermes01
invoke hermes recover testhermes01
invoke hermes stop testhermes01

cat > "$tmp/expected" <<'EXPECT'
launch testhermes01
testhermes01 start
testhermes01 status
testhermes01 recover
testhermes01 stop
EXPECT
diff -u "$tmp/expected" "$trace"

if invoke hermes launch '../unsafe' >"$tmp/fail.log" 2>&1; then
    echo 'Invalid sandbox name unexpectedly accepted.' >&2; exit 1
fi
if invoke hermes destroy testhermes01 >"$tmp/fail.log" 2>&1; then
    echo 'Destructive unsupported operation unexpectedly accepted.' >&2; exit 1
fi
if invoke hermes launch >"$tmp/fail.log" 2>&1; then
    echo 'Missing sandbox name unexpectedly accepted.' >&2; exit 1
fi
diff -u "$tmp/expected" "$trace"

# User-scoped alias registration needs no root/Windows/installer actions.
HOME="$tmp" bash "$ROOT/install.sh" register-cli >"$tmp/registration.log"
HOME="$tmp" bash "$ROOT/install.sh" register-cli >>"$tmp/registration.log"
grep -Fq 'already points to this Linux checkout' "$tmp/registration.log"
HOME="$tmp" "$tmp/.local/bin/aiw" --version >"$tmp/alias-version.log"
grep -Fq 'aiw-nemo' "$tmp/alias-version.log"
mkdir -p "$tmp/conflict/.local/bin"
printf 'unrelated-file\n' > "$tmp/conflict/.local/bin/aiw"
if HOME="$tmp/conflict" bash "$ROOT/install.sh" register-cli >"$tmp/fail.log" 2>&1; then
    echo 'Unexpectedly overwrote foreign aiw launcher.' >&2; exit 1
fi
grep -Fq 'unrelated-file' "$tmp/conflict/.local/bin/aiw"

# Menu: registry selection by NUMBER, provider/model and optional known live
# phase. Status of the selected sandbox is checked before presenting actions.
printf '7\n1\n1\nq\n' | invoke menu >"$tmp/menu.log"
grep -q 'Hermes: launch / stop / start / recover' "$tmp/menu.log"
grep -q '1) testhermes01' "$tmp/menu.log"
grep -q '2) other-hermes' "$tmp/menu.log"
grep -q 'phase: Ready' "$tmp/menu.log"
grep -q 'phase: Stopped' "$tmp/menu.log"
grep -q 'Current NemoClaw sandbox status' "$tmp/menu.log"
printf 'testhermes01 status\nlaunch testhermes01\n' >> "$tmp/expected"
diff -u "$tmp/expected" "$trace"

printf '7\n2\n3\nq\n' | invoke menu >"$tmp/menu.log"
printf 'other-hermes status\nother-hermes stop\n' >> "$tmp/expected"
diff -u "$tmp/expected" "$trace"

# The shell-connect option also uses the registry selector.
printf '4\n1\nq\n' | invoke menu >"$tmp/menu.log"
printf 'testhermes01 connect\n' >> "$tmp/expected"
diff -u "$tmp/expected" "$trace"

# Enter, 0, invalid numbers and bad registry JSON must not abort the menu
# or trigger implicit start/stop/rebuild.
for input in $'4\n\nq\n' $'4\n0\nq\n' $'4\n99\nq\n' \
             $'7\n\nq\n' $'7\n1\n\nq\n' $'7\n1\n0\nq\n' $'7\n1\n99\nq\n'; do
    printf '%s' "$input" | invoke menu >"$tmp/menu.log" 2>&1
    if [[ "$input" == $'7\n1\n'* ]]; then
        printf 'testhermes01 status\n' >> "$tmp/expected"
    fi
    diff -u "$tmp/expected" "$trace"
done
printf '7\n1\n4\nq\n' | FAKE_NEMO_FAIL=yes invoke menu >"$tmp/menu.log" 2>&1
grep -q 'Status could not be verified' "$tmp/menu.log"
grep -q 'Hermes action failed' "$tmp/menu.log"
diff -u "$tmp/expected" "$trace"
printf '7\nq\n' | FAKE_NEMO_BAD_LIST=yes invoke menu >"$tmp/menu.log" 2>&1
grep -q 'Cannot parse upstream sandbox registry' "$tmp/menu.log"
diff -u "$tmp/expected" "$trace"

echo '[OK] NemoClaw lifecycle, numbered registry selection and safe menu cancellation.'
