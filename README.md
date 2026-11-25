# AI Workstation Linux

**Portable Ubuntu agent workstation:** rootless Podman with the official
NVIDIA NemoClaw, OpenShell and Hermes agent stack. Runs on **native Ubuntu**
or inside Ubuntu under WSL. Linux sources, releases, CLI and tests are
independent of the [Windows AI Workstation](https://github.com/SomeSunlight/ai-workstation).

The Linux project manages *host setup* and provides a small operator
entrypoint. **NemoClaw/OpenShell remain the sole owners of sandbox, session,
credential, provider and policy management.** No competing AIW supervisor
or sandbox inventory is introduced.

## Current development status — 2026-11-25

Linux PR #7 and Windows PR #85 are merged. NemoClaw v0.0.145 with
OpenShell 0.0.116 was qualified in the separate `AIW-Nemo-New` WSL.
Owner live-tested the explicitly manual [temporary Error recovery](docs/nemoclaw-recovery.md)
(PR #12): Hermes chat, retained WhatsApp pairing, and subsequent native
stop/start with messaging passed. This is not general crash recovery.
The normal operator workflow remains vendor-owned. PRs #9, #10 and #12
are squash-merged with green exact-head CI. The private-host consent review
and WhatsApp reminder await their next fresh live onboarding check.

The independent Linux repository's initial extraction
([PR #1](https://github.com/SomeSunlight/ai-workstation-linux/pull/1))
is **merged**. This repository provides the Ubuntu 26.04 host installer,
rootless Podman/NemoClaw pins, the separate `aiw` CLI, verification
and offline tests. Linux
[PR #5](https://github.com/SomeSunlight/ai-workstation-linux/pull/5)
was owner-accepted and squash-merged. The operator-first cockpit and
consented reboot preflight are available on `main`. A separate
[Issue #6](https://github.com/SomeSunlight/ai-workstation-linux/issues/6)
tracked NVIDIA v0.0.145 qualification **only on a fresh WSL instance**,
without upgrading or deleting the prior `AIW-Nemo` environment.

The operator has **already exercised the candidate on the actual
`AIW-Nemo` distro** with a new `testhermes03` sandbox. It passed
a complete Windows reboot followed by explicit restoration of
NVIDIA's missing host-loopback address, upstream sandbox startup
and continuation of the **same Hermes session**. The further
convenience change to offer sandbox startup when a user selects
“Continue conversation” was added *after* that reboot test. It has
since **passed a separate owner-reported live test (2026-11-22)**, in
addition to offline CI coverage.
Windows [PR #84](https://github.com/SomeSunlight/ai-workstation/pull/84)
(the penguin shell launcher) is **merged**; the independent pinned
Windows/Linux handoff [PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85)
has **merged**. A working penguin is not proof that the entire
cross-repository production cutover is complete.

## Linux entrypoints

```bash
./install.sh --version
./install.sh status
./install.sh verify
bash bin/aiw-nemo             # menu; read status before changing a sandbox
./install.sh register-cli     # once, as current Linux user (no sudo)
aiw                           # explicit menu; q returns to Linux shell
aiw network                   # read-only IP/Podman/OpenShell status
aiw gateway status            # show shared gateway and reboot-sensitive host alias
```

`status`, `verify` and `--version` make no package, host, sandbox or
repository changes. `./install.sh install` is a **separately confirmed
host installation** for qualified Ubuntu 26.04; it requires sudo and is
not the first step on an existing working NemoClaw host. The official
NemoClaw `onboard` command is always separate and explicit.

Start with [Operator guide](docs/operator.md),
[Fresh NemoClaw v0.0.145 WSL qualification](docs/fresh-nemoclaw-wsl.md) and
[Side-by-side migration](docs/migration.md). Never run rebuild/destroy,
change upstream credentials, or replace the old WSL installation
merely to update the Linux source.

**Operator workflow:** Open a NemoClaw WSL penguin, type `aiw`, choose
**My Hermes sandboxes**, select a sandbox by number, and choose
**New chat**, **Continue last chat**, **Start sandbox** or **Stop sandbox**.
A sandbox's model/provider is recorded by NemoClaw, not AIW; different
sandboxes can use local Strata or OpenRouter and different upstream
policies. Each chat is inside one existing sandbox. The shared gateway
is a separate service; `q` exits only the menu, not Linux or Hermes'
background gateway.

**App-first navigation:** Choosing **Continue most recent conversation**
on a stopped sandbox now offers an explicit **start this sandbox first?**
confirmation, then runs the normal safety preflight and resumes the agent
only after upstream reports `Ready`. No automatic start is performed on
menu entry and no global `last sandbox` registry is introduced. That
readiness interaction is generic enough for future agents; Hermes session
resumption remains its own adapter.

**Windows reboot protection (Linux Issue #3):** NVIDIA's native
Podman alias `169.254.2.2/32` disappeared after a full Windows reboot
while the gateway service remained active. A sandbox then repeatedly
failed to fetch its policy and entered OpenShell `Error`. The AIW
operator now checks this exact host prerequisite **before** starting a
stopped sandbox or launching/resuming a chat. If it is missing, it asks
for explicit permission to re-establish NVIDIA's address with `sudo`
and verifies the result. The normal reboot guard does not rescue already-`Error` sandboxes,
change OpenShell versions or alter Podman container metadata. The separate
manual emergency helper is documented above. The **full Windows reboot and manual repair have been live-tested** with
`testhermes03`; the later conversation-resume menu improvement has
also been successfully tested by the owner (2026-11-22). See
[the evidence and upstream handoff](https://github.com/SomeSunlight/ai-workstation-linux/issues/3)
and [operator guide](docs/operator.md).

The owner has previously verified a native encrypted Hermes backup
outside WSL, but no import test. NemoClaw v0.0.145 is the qualified pin;
**`./install.sh install` is not a supported upgrade shortcut**.
Version changes need a separate, explicit vendor-compatible operation.
Hermes browser/HTML preview and local Strata are tracked by
[Issue #2](https://github.com/SomeSunlight/ai-workstation-linux/issues/2).

## Architecture

| Linux repository | Windows repository |
| --- | --- |
| Ubuntu package/Podman/Ansible pins and installer | Windows host native services, DPAPI and Dispatcher |
| NemoClaw/Hermes CLI and policy delegation | WSL distribution import and desktop penguin shortcut |
| Linux CI and release/version provenance | Independent Windows CI and verified Linux Git commit pin |
| Native Ubuntu or WSL without Windows-specific APIs | Optional launch of an explicitly selected Linux release |

Windows will ultimately pin an immutable Linux commit, not silently
synchronize Linux to a Windows Git branch. Changes to a Linux sandbox
policy then require **no Windows Dispatcher build**.

Repository ownership and user approval rules are specified in
[the migration contract](https://github.com/SomeSunlight/ai-workstation/blob/feat/78-linux-project-handoff/docs/linux-repository-handoff.md).

Both Create sandbox and Resume interrupted onboarding now show the trusted private inference host review before the official wizard. Press Enter to keep the displayed configuration, or explicitly approve exact hostnames if needed. The consent persists across shells and applies only to AIW onboarding/resume. See [operator guide](docs/operator.md#explicit-private-inference-host-consent).
