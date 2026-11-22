#!/usr/bin/env bash
# Offline execution proof: NVIDIA builds the CLI in the selected source checkout,
# not in ~/.nemoclaw/source when its installer is run from a Git checkout.
# No WSL, network, runtime, credentials or host installation.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
function_text="$(sed -n '/^check_receipt() {/,/^}/p' "$ROOT/bootstrap/linux/install.sh")"
[[ "$function_text" == *'build_identity="$source_dir/dist/build-identity.json"'* ]] ||
  { printf 'Build identity must come from selected source checkout.\n' >&2; exit 1; }
(
  tmp="$(mktemp -d)"
  trap 'rm -rf -- "$tmp"' EXIT
  export HOME="$tmp/home"
  source_dir="$HOME/.local/share/aiw-nemoclaw/source"
  mkdir -p -- "$source_dir/dist" "$HOME/.local/bin" "$HOME/.config/ai-workstation"
  git init -q "$source_dir"
  git -C "$source_dir" -c user.name=AIW-Test -c user.email=aiw-test@example.invalid commit --allow-empty -qm 'synthetic vendor revision'
  EXPECTED="$(git -C "$source_dir" rev-parse HEAD)"
  printf '%s\n' "$EXPECTED" > "$HOME/.config/ai-workstation/nemoclaw-installer-ref"
  cat > "$HOME/.local/bin/nemohermes" <<'CLI'
#!/bin/sh
printf 'nemohermes v0.0.145\n'
CLI
  chmod 700 "$HOME/.local/bin/nemohermes"
  printf '{"sourceRevision":"%s"}\n' "$EXPECTED" > "$source_dir/dist/build-identity.json"
  fail() { printf '[XX] %s\n' "$*" >&2; exit 1; }
  json() { printf '%s\n' "$EXPECTED"; }
  eval "$function_text"
  check_receipt >/dev/null
  printf '{"sourceRevision":"%s"}\n' '0000000000000000000000000000000000000000' > "$source_dir/dist/build-identity.json"
  if (check_receipt >/dev/null 2>&1); then
    printf 'Wrong NVIDIA sourceRevision was accepted.\n' >&2
    exit 1
  fi
  rm -f -- "$source_dir/dist/build-identity.json"
  if (check_receipt >/dev/null 2>&1); then
    printf 'Missing NVIDIA build identity was accepted.\n' >&2
    exit 1
  fi
)
printf '[OK] NVIDIA source-checkout build identity: correct pin accepted; mismatched/missing refused.\n'
