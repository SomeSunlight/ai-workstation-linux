# NemoClaw / Hermes recovery — native Linux operator guide

This guide applies to the independent Ubuntu Linux installation with
**rootless Podman**, upstream NVIDIA NemoClaw/OpenShell, and Hermes.
The Windows host, optional WSL distribution bootstrap, local inference
Dispatcher and their credentials are managed separately. This project
does not implement a second supervisor or sandbox registry.

## Normal operation

In a regular Linux terminal, **outside** an OpenShell sandbox:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes list --json
nemohermes <sandbox> status
nemohermes launch <sandbox>
```

`list --json` is the authoritative current inventory. In the Linux
`bash bin/aiw-nemo menu`, option 7 presents available registered
sandboxes by **number** before offering lifecycle actions. Option 4
opens another **separate shell**, not the existing Hermes conversation.

Closing Hermes's interactive terminal does **not** imply the managed
sandbox is stopped. When there are no live agent sessions that should
remain connected, the normal lifecycle is:

```bash
nemohermes <sandbox> status
nemohermes <sandbox> stop
nemohermes <sandbox> status
nemohermes <sandbox> start
nemohermes launch <sandbox>
```

Stopping a managed sandbox is distinct from removing it; do not treat
a normal stop as a backup. Check project files and upstream persistence
before host replacement or a fresh installation.

## Before lifecycle testing: record a restorable backup gate

Follow the [Hermes backup and transfer guide](hermes-data-safety.md).
**Hermes itself** provides `hermes backup` and `hermes import`, separate
from NemoClaw's installer-facing `nemohermes backup-all`. Prefer the
official Hermes user-data backup rather than a custom SQLite/archiver
workaround. Confirm the command exists in the *installed Hermes image*
using `hermes backup --help` before running it. Never use rebuild,
destroy or import to manufacture or test a backup of the live sandbox.

## External inference host reboot: restore the upstream dependency first

**Observed on 2026-11-19** (owner's existing `AIW-Nemo` /
`testhermes01`): after an unexpected Windows Update reboot of the
separate Speedy inference host, its local Dispatcher/Caddy services
were not running. NemoClaw's `connect` refused with
`curl_exit=56`, an untrusted `inference.local` probe, and
`compatible-endpoint/sparringpartner` route health not verified.
The separate HTTPS `/v1/models` unauthenticated connectivity probe
returned `HTTP 000` (connection refused). After the operator restarted
the **existing Windows inference services**, the same request returned
`HTTP 401` (reachable, auth required), and `nemohermes
testhermes01 connect` immediately worked. No NemoClaw recover,
rebuild, onboard or route change was necessary.

**Triage order:** check the independent Windows inference-service
status first; from the Linux host, a bounded HTTPS **unauthenticated**
probe returning 401 shows reachable authenticated service, but not
successful model completion. If it reports 000, troubleshoot that
external service and HTTPS path before touching OpenShell. Only after
restoring the external dependency retry ordinary `connect`; if
still unhealthy, collect a redacted `doctor --json` report **without
`--fix`** before choosing any mutation. This illustrates a
cross-machine dependency, not an automatic Linux recovery failure.

## Diagnose before recovery

1. Identify the exact intended sandbox with `nemohermes list --json`;
   never assume the current default is the intended one.
2. Inspect `nemohermes <sandbox> status` and the bounded output from
   upstream `nemohermes <sandbox> logs` where supported.
3. For an existing sandbox with unhealthy gateway/forwards, use the
   documented upstream `nemohermes <sandbox> recover` **only when
   needed**. Inspect the result, then re-run `status`.
4. Do not confuse a missing `openshell-gateway.service` user systemd
   unit with proof that no NemoClaw-owned gateway exists. Verify the
   actual vendor-managed gateway owner and status.
5. If credentials, policy or inference-route registration is suspected,
   stop and review upstream evidence before running onboarding or a
   provider change. No Windows/WSL repair command is a fix for an
   upstream credential failure.

`start`, `recover`, `rebuild` and `destroy` are **different**.
In particular, vendor rebuild may include backup/delete/recreate/restore
and can require provider/search credentials that are not part of an
ordinary restart. **Never use rebuild/destroy/prune as an automatic
fallback**, and never re-onboard a working sandbox merely to refresh
Linux source code.


## Temporary emergency recovery: OpenShell 0.0.116 only (#11)

Unsupported, manual last resort for the disposable test WSL, not a normal
AIW lifecycle operation. The upstream precedent is
[OpenShell #3440, successful phase-only recovery](https://github.com/ai-openshell/openshell/issues/3440#issuecomment-5744288601)
(macOS/Docker, not rootless Podman). It changed only the protobuf phase
from Error (3) to Stopped (7), then used the native start command.
The pinned [protobuf schema](https://github.com/ai-openshell/openshell/blob/v0.0.116/proto/openshell.proto)
defines the fields used by this helper. No policy or credential changes.
No automatic backups or recreation. A failed repair may require reinstalling
the disposable WSL; never use this on the productive distro.

From the **test WSL host**, with no active sandbox containers or concurrent
operators, identify the sandbox and verify the actual gateway database path:
 
```bash
openshell --version
openshell sandbox get testhermes04
systemctl --user show nemoclaw-openshell-gateway.service -p MainPID
```

Inspect the active gateway process's open database file locally (do not
share environment variables or credentials). The expected path is
`~/.local/state/nemoclaw/openshell-docker-gateway/openshell.db`.
If it differs, stop; the helper is not qualified for that installation.
Use the UUID from OpenShell, not a Podman container ID:

```bash
python3 bin/openshell-0116-repair.py testhermes04 0c432179-110f-4924-add7-fe98de73024f
```

This defaults to a read-only eligibility check. It deliberately refuses
different failure conditions, missing volumes, or running containers.
For MainProcessExited with a recorded exit code, only the phase is changed;
[the pinned native Starting transition](https://github.com/ai-openshell/openshell/blob/v0.0.116/crates/openshell-server/src/compute/mod.rs)
clears the exit code and retains the previous supervisor instance ID. If blocked, do not relax the checks.

Only after a successful dry run and explicit acceptance of the risk:
 
```bash
aiw gateway stop
python3 bin/openshell-0116-repair.py testhermes04 0c432179-110f-4924-add7-fe98de73024f --apply
aiw gateway start
openshell sandbox get testhermes04
```

Restart the shared gateway even if the helper fails. If and only if the
original sandbox is now Stopped, use the supported start path:

```bash
aiw hermes start testhermes04
openshell sandbox get testhermes04
```

Check original UUID, volumes, Hermes chat/inference and user data.
No runtime acceptance yet. Remove this helper when the vendor pin provides
native Error recovery. Do not use it to clear arbitrary Error states.

## Security and data

- Do not post gateway tokens, API keys, full vendor diagnostics with
  private endpoint URLs, private LAN IPs, or host user paths to public Git.
- Official NemoClaw/OpenShell manages credentials, traffic permissions,
  DNS pinning and sandbox authority; AIW does **not** bypass these.
- A private inference endpoint may require a narrow, operator-approved
  exact-host trust decision during provider enrollment. Do not replace
  this with unrestricted private-network access or a DNS/SSRF bypass.
- Existing workspace files, Hermes conversation state, export artifacts
  and gateway credentials may live in **different** authorities. Back up
  what matters and verify restorability before any clean reinstall or
  sandbox replacement.
- If a crash cannot be recovered safely, preserve the original sandbox
  and its evidence while testing a **new sandbox identity** separately.

## Repository/source problems are not runtime recovery

`git pull` in Windows does not update a separate Linux checkout.
The Linux CLI's `--version` reports the checkout **actually running**;
`./install.sh verify` checks pinned native Ubuntu/Podman/vendor host
prerequisites without touching the managed sandbox. Updating a
standalone Git checkout is not a reason to run onboarding or reinstall
Hermes.

For source migration and owner-acceptance gates, see
[docs/migration.md](migration.md) and [Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
For the original, historically observed incidents and evidence, see
[Windows/WSL pilot Issue #83](https://github.com/SomeSunlight/ai-workstation/issues/83).
