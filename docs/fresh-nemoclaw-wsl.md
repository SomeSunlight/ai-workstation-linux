# Fresh NemoClaw v0.0.145 WSL qualification — Issue #6

This is a **side-by-side first installation**, **not** an upgrade or repair of
an existing sandbox or registered distribution. The official NVIDIA source
installer remains the only NemoClaw installer, selected by the exact AIW pin.
No standalone OpenShell version bump, source fork, or `curl | bash` is involved.

## Reviewed release

- Previous NemoClaw source: `82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f` (v0.0.144).
- NVIDIA annotated Git tag `v0.0.145` resolves to commit `6f36feffb7a0f448194eafef3042e7ad47faa0de`.
- Published November 18/19 2026; release notes:
  https://docs.nvidia.com/nemoclaw/latest/user-guide/openclaw/release-notes/2026/11/18
- The vendor release includes Hermes routing preflight changes and installer /
  recovery changes. Treat vendor first-run prompts and actual OpenShell version
  as authoritative; AIW does not choose an independent OpenShell version.
- The existing Podman host-loopback `169.254.2.2/32` reboot issue has **not**
  been qualified as fixed in this release. The AIW consented preflight remains.
- Source pin, installed AIW receipt, exact checkout revision, and NVIDIA
  generated CLI build identity must agree for `verify` to pass.

## Inventory and stop gates (owner observed, 2026-11-22)

| WSL name | Observed identity | Policy |
| --- | --- | --- |
| `Ubuntu-24.04` | Productive WSL (owner) | **Never touch** |
| `Ubuntu-26.04` | Internally `VERSION_ID=24.04`; historical AIW/Goose projects, backups and files | **Do not reuse or delete without separate inspection and approval** |
| `AIW-Nemo` | Existing v0.0.144, old `testhermes02` error | **Retain until new install accepted** |
| `AIW-Nemo-New` | Proposed new name only | Install **only after verified availability** |

WSL names do not establish the guest OS version. `wsl --list --verbose` and
`/etc/os-release` must agree with operator expectations before host install.
The unremovable sandbox is intentionally left in the old whole distro;
neither NemoClaw registry nor Podman internal state is manually edited.

## Creating a clean instance (Windows PowerShell, owner-run)

Read the available Ubuntu distribution names before installation:

```powershell
wsl --list --online
wsl --list --verbose
```

If `Ubuntu-26.04` is advertised as an installable **source distribution**,
and `AIW-Nemo-New` is not registered, create a **separately named** instance:

```powershell
wsl --install -d Ubuntu-26.04 --name AIW-Nemo-New
```

This intentionally does **not** use the existing WSL instance named
`Ubuntu-26.04`; `--name` creates a distinct registered instance. Complete
Ubuntu's normal first-user setup. Before any AIW installation, verify:

```powershell
wsl -d AIW-Nemo-New --exec cat /etc/os-release
wsl -d AIW-Nemo-New --exec sh -c 'ps -p 1 -o comm='
```

Require `VERSION_ID="26.04"` and systemd as PID 1. If these checks fail,
**stop**; do not attempt an in-place Ubuntu upgrade or change the installer
to accept 24.04. No full Windows restart is part of routine acceptance.

## Linux install and acceptance (only inside the newly created instance)

From the **new user's Linux shell**, use the owner-reviewed PR checkout while
testing, on its Linux filesystem, not `/mnt/c`:

```bash
cd ~
git clone https://github.com/SomeSunlight/ai-workstation-linux.git
cd ai-workstation-linux
git fetch origin feat/6-nemoclaw-0145-fresh-wsl
git switch --track origin/feat/6-nemoclaw-0145-fresh-wsl
./install.sh --version
./install.sh status
```

Only after the draft PR's two offline CI jobs pass and the branch/commit is
confirmed, run `./install.sh install` with its ordinary visible consent
prompts. It installs pinned Ubuntu/Podman/Ansible and invokes NVIDIA's own
`scripts/install.sh` from the exact checked-out NVIDIA commit, deferring
agent onboarding. Afterward:

```bash
./install.sh verify
aiw gateway status
nemohermes --version
openshell --version
```

`verify` is read-only and requires matching AIW receipt, vendor source,
NVIDIA-generated build identity, and rootless Podman. Onboarding with Hermes
and the first new sandbox is a **separate explicit action**. Use the AIW menu
to check: gateway, sandbox creation, `Ready`, Hermes provider/model request,
stop, start, and continuation of the same chat. Do not require a Windows reboot.
If any test fails, retain the old distributions and report the full result.

## Only after acceptance: separate retirement decisions

- Ask for exact distro-by-name confirmation and approval **before** any
  `wsl --unregister`, which irrevocably deletes the named root filesystem.
- Retire old `AIW-Nemo` as a **whole distro**, not by tampering with
  `testhermes02` records or Podman storage.
- Audit historical files in the **misnamed** `Ubuntu-26.04` separately
  before considering its retirement. Never infer it is disposable.
- Keep `Ubuntu-24.04` untouched. Move the Windows launcher and immutable
  Linux commit pin in a separately accepted Windows PR (#85), after Linux merge.
