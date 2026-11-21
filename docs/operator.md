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
From the Windows penguin shortcut, enter WSL, type `aiw` and choose:

1. **My Hermes sandboxes:** Select one from the official NemoClaw registry
   by **number**, showing provider, model and the last reported phase.
   Selected-sandbox actions are **new chat**, **continue latest Hermes
   conversation**, **list/resume another conversation**, **start stopped
   sandbox**, **stop sandbox while keeping data**, **open sandbox shell**,
   **full status** and **advanced recovery**.
2. **Create another sandbox:** The official NemoClaw Hermes onboarding
   wizard, including its provider/security-policy selection. This is *not*
   required to start an existing sandbox.
3. **Shared gateway:** Observe gateway/Podman socket and the native
   sandbox-to-host address; explicitly prepare it, start or stop the
   shared gateway. Stop requires typing `STOP` because all sandboxes
   depend on this service.
4. **Advanced:** Host health, installer verification, network inventory,
   official NemoClaw help and *onboarding* resume (not chat resume).

When a user selects **New conversation**, **Continue latest conversation**,
**List other conversations**, or **Open sandbox shell** on a **Stopped** sandbox,
the operator explains that the sandbox is not running and asks:

```text
Sandbox <name> is stopped. Its files and agent conversations are preserved.
Start this sandbox before continuing the most recent Hermes conversation? [y/N]
```

Only an explicit yes starts that *selected* sandbox using the already
qualified native-Podman host-address check and official upstream lifecycle.
The subsequent Hermes/session action runs **only after** a fresh upstream
status reports `Ready`. Declining changes nothing; `Error` and unknown
phases never trigger an automatic restart. This is general sandbox
preparation, separate from Hermes-specific conversation resume.

An upstream status JSON gives the selected sandbox phase. **OpenShell
`Error` is not `Stopped`**; the operator blocks attempts to start or
recover it. Unknown phases block startup rather than guessing. The compact
menu never prints the whole security policy; full vendor status remains an
explicit action and may include private details.

**Lifecycle distinction:** `q` exits AIW into the Linux shell;
`/quit` exits a Hermes *conversation*, not its Sandbox; `start`
starts an existing *stopped sandbox*, not a conversation or the common
gateway; `stop` stops only that sandbox and preserves its upstream
data. Several sandboxes may run concurrently and separate Linux penguins
can attach to different ones.

**Resume:** The menu requests the official in-sandbox
`hermes --resume latest` through the NemoClaw interactive exec bridge.
No IDs or session catalogue are stored by AIW. If the installed
OpenShell/terminal does not render this interactive exec correctly,
use **Open sandbox shell** and type `hermes --continue` inside; this
was previously verified. The **direct Hermes session resume** has been live-qualified: after a
full Windows reboot and a separately approved sandbox start, the owner
resumed the exact previous session ID. The later **one-step menu offer**
to start a Stopped sandbox first has only offline mock/CI coverage and
is a separate, optional operator acceptance check.

**No AIW-owned sandbox registry, background supervisor, custom
backup engine, automatic rebuild/destroy or network-policy bypass**
is introduced. Cancellation (Enter/0) never mutates the vendor runtime.

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

The **Windows project** provides two NemoClaw desktop icons through
[merged PR #84](https://github.com/SomeSunlight/ai-workstation/pull/84).
One opens a *real WSL Linux shell* in
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

The operator has already used the **project penguin** to enter WSL
and resume Hermes after Windows reboot. This qualifies the shell entry
point, **not** the separate pinned production handoff still pending in
[Windows PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85).
Do not apply that remaining cutover implicitly.

## Windows restart: preflight before creating another Error sandbox

A full Windows reboot may remove NVIDIA's native Podman host-loopback
address `169.254.2.2/32`, even though the user-systemd
`nemoclaw-openshell-gateway.service` is already active and listening on
8080. Registered Podman containers still map `host.openshell.internal`
to that missing address. A policy fetch then fails five times and OpenShell
can leave the sandbox in sticky `Error`. The four-stage controlled
reproduction and exact NVIDIA source cause are preserved in
[Linux Issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3).

**Safety contract for AIW actions:** Read-only startup shows whether
the address exists on Linux `lo`. Before **starting a stopped sandbox,
launching Hermes or resuming a conversation**, AIW verifies the upstream
sandbox phase and the host address. If it is missing, AIW asks permission
to run NVIDIA's exact bounded host preparation:

```bash
sudo -- ip address replace 169.254.2.2/32 dev lo
```

The operator explicitly approves a possible sudo password prompt;
AIW then verifies the interface assignment. If it conflicts, cannot
be inspected or permission is declined, **no sandbox start/launch is
attempted**. A stopped shared gateway must be started separately under
**Shared gateway**. No address is changed at *menu startup*, no Podman
container metadata is rewritten and no already-`Error` sandbox is
automatically resurrected. **Direct** use of `nemohermes` bypasses
the AIW guard.

For a non-interactive read-only check use `aiw gateway status`;
`aiw gateway prepare` explicitly requests interactive approval.
The preparation lasts until the Linux network stack next resets; it is
*not* a new boot service. Existing data in an `Error` sandbox is not
necessarily lost; keep it unless a later explicit vendor cleanup is
approved. For source-level evidence and safe upstream follow-up see
[Issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3).

The recurring Node SQLite `ExperimentalWarning` category is suppressed
only for NemoClaw child processes (`NODE_OPTIONS=--disable-warning=ExperimentalWarning`).
Other warnings and errors are not suppressed. The separate Speedy
Dispatcher remains outside this Linux operator's authority.

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

The independent installer **passed** a clean WSL Ubuntu 26.04
host trial on 2026-11-19: Ansible completed without failures,
NemoClaw v0.0.144 was installed, and `./install.sh verify` passed.
**Native bare-metal Ubuntu remains untested.** Separately, the owner
successfully used the existing `AIW-Nemo` environment to onboard
a new `testhermes03` sandbox and qualify its Windows-reboot recovery;
this does not qualify an end-to-end new Hermes sandbox onboarding
*on the clean-room installation*. Do **not** run the host installer
on existing working `AIW-Nemo` merely to update the source.

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
as a proven repair of stale `HostConfig.ExtraHosts`. The full native Hermes ZIP has been encrypted off WSL; **no application
import or in-place rescue of the two Error-phase sandboxes was tested**.
A different sandbox, `testhermes03`, **did pass a complete Windows
reboot**, explicit NVIDIA host-address restoration, `Ready` status
and preserved Hermes conversation history. Do not conflate this
successful restart with a verified ZIP restore or an automatic boot fix.

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

## Operational acceptance and deferred improvements (2026-11-22)

- **Passed live:** owner used `testhermes03` with the pinned
  NemoClaw/OpenShell stack; stopped it, restarted Windows, observed
  the missing native-Podman host address, explicitly approved its
  restoration, started the existing sandbox and resumed the **same
  Hermes conversation**. The retained transcript does not separately
  demonstrate a new, post-restart inference answer.
- **Passed offline:** the latest PR #5 menu offers to start a
  **Stopped** sandbox only when an agent action is requested and the
  user explicitly approves. The already-qualified host preparation
  runs before vendor start. This last UX convenience is **not** yet
  separately live-tested; merge acceptance belongs to the owner.
- **Follow-up, not a PR #5 blocker:** NVIDIA upstream fix and regression
  test ([Issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3)),
  reviewed NemoClaw upgrade from current v0.0.144 pin,
  Windows launcher revision warning/pinned handoff and the
  missing `tirith` scanner observed inside Hermes.
- **Design boundary:** a future multi-agent operator should reuse the
  generic *selected sandbox readiness/start* step, while keeping
  Hermes conversation handling an agent-specific adapter. No
  parallel AIW sandbox/session registry is justified.
