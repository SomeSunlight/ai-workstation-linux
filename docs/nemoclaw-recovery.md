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

Follow the [Hermes data-safety and restore checklist](hermes-data-safety.md).
The first step is a read-only inventory of recognized Hermes state paths,
not a sandbox stop. The upstream `backup-all` operation serves installer
upgrades and is not a general user-facing snapshot/restore API; do not
use rebuild/destroy to manufacture an ad hoc backup.

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
