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
./install.sh register-cli          # one-time user-local registration; no sudo
aiw                                # launch the menu explicitly from any directory
```

Network addresses, Podman host aliases and before/after snapshots are
available through `aiw network`. The regular status/menu reads this
inventory only; the separate disposable network test requires an
**explicit `--probe`**, and never modifies the Hermes sandbox. For exact
private snapshot commands, read the
[controlled recovery and restart qualification](restart-qualification.md).

The operator menu delegates to **upstream** `nemohermes` commands.
Menu item 7 selects from the official registry **by number**; it displays
the registered provider/model and any **known** live phase, and fetches the
selected sandbox's authoritative status before actions. Unknown phases are
labelled **not checked**, never guessed. Menu item 4 also selects an existing
sandbox by number, opening a separate shell rather than another session in
the same terminal. Enter/0 cancels **without exiting Linux or triggering
a lifecycle operation**.
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

## One command, two entry directories

`./install.sh register-cli` registers a collision-protected
`~/.local/bin/aiw` executable pointing to **this exact Linux checkout**.
It is idempotent, uses no sudo, and neither touches NemoClaw nor changes
shell profiles. If another command already owns the name, it stops rather
than overwriting it. Log in to a new shell so `~/.local/bin` is on PATH,
or use `export PATH="$HOME/.local/bin:$PATH"`.

The **Windows project**, once its launcher cutover is explicitly reviewed,
provides two NemoClaw desktop icons: one opens a *real WSL Linux shell* in
`~/ai-workstation-linux`, the other in `~`. Neither starts the menu
automatically. Inside either shell, type `aiw` to open the menu.
`q` returns to that Linux shell; type `exit` explicitly to close WSL.
The older one-click icon that ran `bash ./bin/aiw-nemo` as a one-off
WSL process does **not** have this behavior and can return straight to
Windows PowerShell when the menu quits.

The reliable manual entry from Windows PowerShell uses an **absolute**
Linux home path; in the observed Windows environment,
`--cd ~` unexpectedly retained the Windows current directory:

```powershell
wsl -d AIW-Nemo -u moresunlight --cd /home/moresunlight
```

Do not switch the working production shortcut to the Linux candidate
until both projects have passed the reviewed cutover gates.

## An unexpected Windows reboot and a sandbox start error

If `nemohermes <name> start` reports `OpenShell sandbox entered error
while waiting for readiness`, it does **not** prove Hermes data loss.
NemoClaw's source already tolerates transient startup Error states;
persisting beyond that requires diagnosis. **Do not blindly repeat
start/recover/rebuild or re-onboard**. From the Linux host, inspect
`systemctl --user is-active podman.socket`, the selected sandbox's
`nemohermes <name> status`, read-only `doctor --json` and bounded
OpenShell sandbox logs. Keep log content and credentials private.
The separate Speedy Dispatcher may also require its own service restart
after Windows Update; that is not itself an OpenShell repair.

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

The independent installer **has passed** a fresh WSL Ubuntu 26.04
host trial on 2026-11-19: Ansible completed with zero failures,
NemoClaw v0.0.144 was installed, and a subsequent independent
`./install.sh verify` passed. Native bare-metal Ubuntu and a full
new Hermes sandbox onboarding have **not** been tested. Do **not**
run it on the existing working `AIW-Nemo` merely because this
repository was cloned: follow the reviewed cutover plan instead.

## Security and persistence

The repository contains install **specifications**, not secrets,
user-specific hostname/IP values, runtime sessions, or workspace files.
Keep credentials in the upstream gateway or your password manager.
Never copy private credentials, the entire WSL home, or `~/.nemoclaw`
into Git. Allowing one trusted private Dispatcher host must remain
an explicit, narrow operator decision; do not disable DNS pinning/SSRF
protections or make a blanket private-network exception.

The November 20 owner incident demonstrates a stopped Hermes sandbox
that was subsequently stuck in OpenShell `Error`: the persisted
Podman host alias no longer matched the reachable host-gateway alias
after Windows/WSL reboot, so OpenShell policy fetch repeatedly failed
and the container exited 1. The concrete evidence and **bounded
owner-approved recovery gate** are in
[controlled recovery and restart qualification](restart-qualification.md).
Do not treat `recover`, a host gateway restart or `podman network reload`
as a proven repair of stale `HostConfig.ExtraHosts`. The full native
Hermes ZIP has been encrypted off WSL, but **no in-place restore,
application import or cold-reboot recovery test has yet passed**.

A clean shutdown/restart is not a rebuild. Use upstream
`status -> stop -> status -> start -> launch` **only after**
verifying that the specific running sandbox can safely be interrupted.
For unavailable gateways/forwards use upstream `recover` after
diagnosis. A forced crash test follows successful routine restarts, not
the other way round.

## Owner acceptance: live Hermes data safety

Before any destructive migration or experimental recovery of the existing
`testhermes01` sandbox, follow the [Hermes native backup and transfer
guide](hermes-data-safety.md). The owner has successfully created and
CRC-verified the official full Hermes ZIP and protected an encrypted
copy on another Windows drive (2026-11-20; physical disk independence not verified). Never publish
configuration, environment files, logs, credential archives or
sensitive inventories.
