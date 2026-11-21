# AI Workstation Linux

**Portable Ubuntu agent workstation:** rootless Podman with the official
NVIDIA NemoClaw, OpenShell and Hermes agent stack. Runs on **native Ubuntu**
or inside Ubuntu under WSL. Linux sources, releases, CLI and tests are
independent of the [Windows AI Workstation](https://github.com/SomeSunlight/ai-workstation).

The Linux project manages *host setup* and provides a small operator
entrypoint. **NemoClaw/OpenShell remain the sole owners of sandbox, session,
credential, provider and policy management.** No competing AIW supervisor
or sandbox inventory is introduced.

## Current development status

**Migration candidate, not an approved deployment.** Extraction follows
[Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
Development takes place in a draft PR on
`feat/78-linux-bootstrap-extraction`, not on `main`.

This repository already contains the extracted Ubuntu 26.04 Ansible
roles, exact NemoClaw vendor commit and Podman version pins, a standalone
Linux installer, a read-only verifier, an offline Git-aware version
display, and focused contract tests. The existing `AIW-Nemo` distro
and `testhermes01` sandbox have **not** been changed.

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

Start with [Operator guide](docs/operator.md) and
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

**Windows reboot protection (Linux Issue #3):** NVIDIA's native
Podman alias `169.254.2.2/32` disappeared after a full Windows reboot
while the gateway service remained active. A sandbox then repeatedly
failed to fetch its policy and entered OpenShell `Error`. The AIW
operator now checks this exact host prerequisite **before** starting a
stopped sandbox or launching/resuming a chat. If it is missing, it asks
for explicit permission to re-establish NVIDIA's address with `sudo`
and verifies the result. It does not rescue already-`Error` sandboxes,
change OpenShell versions or alter Podman container metadata. The new
workflow **still requires owner testing after another full Windows
restart**; see [the evidence and upstream handoff](https://github.com/SomeSunlight/ai-workstation-linux/issues/3)
and [operator guide](docs/operator.md).

The owner has previously verified a native encrypted Hermes backup
outside WSL, but no import test. The latest NemoClaw release is
v0.0.145 (2026-11-18), one release newer than the pinned v0.0.144;
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
