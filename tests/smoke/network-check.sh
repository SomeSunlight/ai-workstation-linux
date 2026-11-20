#!/usr/bin/env bash
# Offline regression: network diagnostics are read-only unless explicitly probed.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH"
export FAKE_PODMAN_TRACE="$TMP/podman-trace"
export FAKE_HOST_ALIAS="169.254.2.2"
: > "$FAKE_PODMAN_TRACE"

cat > "$TMP/bin/nemohermes" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == "list --json" ]]; then
  printf '%s\n' '{"sandboxes":[{"name":"testhermes01","provider":"compatible-endpoint","model":"sparringpartner","endpointUrl":"https://example.invalid/v1?secret=DO_NOT_RECORD"}]}'
  exit 0
fi
exit 96
MOCK
cat > "$TMP/bin/ip" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  "-j -4 addr show") echo '[{"ifname":"eth0","addr_info":[{"family":"inet","local":"172.29.199.253","prefixlen":20}]}]' ;;
  "-j -4 route show default") echo '[{"dst":"default","gateway":"172.29.192.1","dev":"eth0"}]' ;;
  *) exit 95 ;;
esac
MOCK
cat > "$TMP/bin/ss" <<'MOCK'
#!/usr/bin/env bash
echo 'LISTEN 0 128 0.0.0.0:8080 0.0.0.0:*'
MOCK
cat > "$TMP/bin/getent" <<'MOCK'
#!/usr/bin/env bash
echo '192.0.2.1 STREAM example.invalid'
MOCK
cat > "$TMP/bin/podman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_PODMAN_TRACE"
case "${1:-} ${2:-}" in
  "network inspect")
    echo '[{"name":"openshell-docker","subnets":[{"subnet":"10.89.0.0/24","gateway":"10.89.0.1"}]}]'
    ;;
  "ps -a")
    echo 'openshell-default--testhermes01-4072fe43-d2fb-4085-8231-26dce997c1ef'
    ;;
  "inspect "*)
    printf '[{"State":{"Status":"exited","ExitCode":1,"OOMKilled":false},"HostConfig":{"NetworkMode":"bridge","ExtraHosts":["host.containers.internal:%s","host.openshell.internal:%s"]},"ImageName":"fake-cached-image:local"}]\n' "$FAKE_HOST_ALIAS" "$FAKE_HOST_ALIAS"
    ;;
  "run --rm")
    echo 'ALIAS 169.254.1.2'
    echo 'TCP 169.254.1.2 OK'
    echo "TCP $FAKE_HOST_ALIAS FAIL"
    ;;
  *) exit 92 ;;
esac
MOCK
chmod +x "$TMP/bin/"*

python3 "$ROOT/bin/aiw-network-check.py" --sandbox testhermes01 \
  --save "$TMP/before.json" >"$TMP/first.log"
grep -Fq 'Stored host alias: host.containers.internal => 169.254.2.2' "$TMP/first.log"
grep -Fq 'container reachability NOT established' "$TMP/first.log"
grep -Fq 'Private snapshot created (0600)' "$TMP/first.log"
[[ "$(stat -c %a "$TMP/before.json")" == 600 ]] || exit 1
grep -Fq '169.254.2.2' "$TMP/before.json"
if grep -Fq DO_NOT_RECORD "$TMP/before.json"; then echo 'Secret URL query leaked into network snapshot' >&2; exit 1; fi
if grep -q '^run ' "$FAKE_PODMAN_TRACE"; then echo 'Read-only inventory unexpectedly started a container' >&2; exit 1; fi

if python3 "$ROOT/bin/aiw-network-check.py" --sandbox testhermes01 \
    --save "$TMP/before.json" > "$TMP/conflict.log" 2>&1; then
  echo 'Existing private snapshot was overwritten' >&2; exit 1
fi
grep -Fq 'not written' "$TMP/conflict.log"

export FAKE_HOST_ALIAS="169.254.1.2"
python3 "$ROOT/bin/aiw-network-check.py" --sandbox testhermes01 \
  --compare "$TMP/before.json" >"$TMP/diff.log"
grep -Fq -- '-        "host.containers.internal": "169.254.2.2"' "$TMP/diff.log"
grep -Fq -- '+        "host.containers.internal": "169.254.1.2"' "$TMP/diff.log"
if grep -q '^run ' "$FAKE_PODMAN_TRACE"; then echo 'Comparison unexpectedly started a container' >&2; exit 1; fi

export FAKE_HOST_ALIAS="169.254.2.2"
python3 "$ROOT/bin/aiw-network-check.py" --sandbox testhermes01 \
  --probe >"$TMP/probe.log"
grep -Fq 'Fresh host gateway: 169.254.1.2' "$TMP/probe.log"
grep -Fq 'TCP 169.254.1.2: OK' "$TMP/probe.log"
grep -Fq 'TCP 169.254.2.2: FAIL' "$TMP/probe.log"
grep -q '^run --rm --pull=never' "$FAKE_PODMAN_TRACE"

echo '[OK] Private network snapshot, comparison and explicit disposable-probe contracts.'
