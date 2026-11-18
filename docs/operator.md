# Operating the independent Linux workstation

This repository owns the **Linux host** installation and operator entrypoint
for rootless Podman + upstream NVIDIA NemoClaw/OpenShell/Hermes.
It does not run or configure Windows, WSL images, Speedy, Dispatcher,
DPAPI or any other native Windows service.

## Commands

```bash
./install.sh --version             # local release + branch@commit[, dirty]
./install.sh status                # read-only; no sudo or package changes
./install.sh verify                # read-only Ubuntu, Podman and pinned CLI checks
bash bin/aiw-nemo --version        # Linux Nemo operator revision
bash bin/aiw-nemo                  # interactive NemoClaw/Hermes operator
```

The operator menu delegates to **upstream** `nemohermes` commands.
Menu item 7 selects from the official registry **by number** before offering
launch/start/stop/status/recover. Menu item 4 attaches a second shell to an
existing sandbox, not to another terminal's conversation. Enter/0 cancels.
No AIW-owned sandbox registry, automatic rebuild/destroy or network-policy
bypass is involved.

To inspect a sandbox and its current session attachments without making
changes, use:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes list --json
nemohermes <sandbox-name> status
```

**Avoid sharing JSON fields containing hostnames, internal URLs, user paths
or credentials.** The vendor redacts recognized credentials but logs are
not a safe way to share all local infrastructure details.

## Explicit installation on a clean Ubuntu 26.04 host

```bash
./install.sh install
```

The install action requires a confirmation and Linux sudo authentication.
It installs the reviewed Ubuntu Podman package, a pinned uv/Ansible
automation environment and the exact upstream NemoClaw Git revision.
It **defers official NemoClaw onboarding**, which is the only supported
way to create/configure Hermes and its OpenShell policies. It never
destroys or rebuilds an existing sandbox. The systemd user Podman socket
must pass the rootless/cgroups-v2/Netavark checks.

The Linux install path is not yet independently qualified on a fresh
Ubuntu machine. Do **not** run it on the existing working AIW-Nemo
distribution merely because this repository was cloned: first perform
the read-only migration checks below and review the planned cutover.

## Security and persistence

The repository contains install **specifications**, not secrets,
user-specific hostname/IP values, runtime sessions, or workspace files.
Keep credentials in the upstream gateway or your password manager.
Never copy private credentials, the entire WSL home, or `~/.nemoclaw`
into Git. Allowing one trusted private Dispatcher host must remain
an explicit, narrow operator decision; do not disable DNS pinning/SSRF
protections or make a blanket private-network exception.

A clean shutdown/restart is not a rebuild. Use upstream
`status -> stop -> status -> start -> launch` **only after**
verifying that the specific running sandbox can safely be interrupted.
For unavailable gateways/forwards use upstream `recover` after
diagnosis. A forced crash test follows successful routine restarts, not
the other way round.
