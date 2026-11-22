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
| `AIW-Nemo-New` | Actual fresh Ubuntu 26.04; NemoClaw CLI 0.0.145 installed; full host verification pending fix | **Preserve; resume via Windows AIW** |

WSL names do not establish the guest OS version. `wsl --list --verbose` and
`/etc/os-release` must agree with operator expectations before host install.
The unremovable sandbox is intentionally left in the old whole distro;
neither NemoClaw registry nor Podman internal state is manually edited.

## Preferred operator path: Windows AIW owns fresh WSL provisioning

The approved orchestration target is **Windows
[Draft PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85)**.
It creates `AIW-Nemo-New` using the SHA-256-pinned official Ubuntu 26.04.1
WSL image, sets up only this distribution's user/systemd configuration, then
invokes this project's Linux installer at an **immutable Git commit**.
Manual `wsl --install`, Linux `git clone`, apt/uv/Ansible, and NemoClaw
installation steps are **not** normal owner tasks.

From the owner-reviewed Windows PR #85 checkout:

```powershell
./install-linux-workstation.ps1 -Action Install
```

Then inspect read-only status/verification using the same Windows entrypoint:

```powershell
./install-linux-workstation.ps1 -Action Status
./install-linux-workstation.ps1 -Action Verify
```

The installer must never adopt, unregister or replace `Ubuntu-24.04`,
the historical misnamed `Ubuntu-26.04`, or `AIW-Nemo`. Require real
`VERSION_ID=26.04`, rootless Podman, pinned vendor checkout and AIW
receipt. OpenShell compatibility belongs to NVIDIA's official installer;
do not independently install or update it.

### Actual first-run acceptance, 22 Nov 2026

1. Before a Windows restart, twice attempting the new distro import failed
   after 30 seconds with Microsoft `Wsl/Service/RegisterDistro/WSAETIMEDOUT`.
   No new distro was registered. A normal Windows restart resolved that
   registration failure on the next attempt; no global `wsl --shutdown`,
   manual cleanup or WSL reinstall was needed.
2. The Windows orchestrator then created `AIW-Nemo-New`, verified actual
   Ubuntu 26.04, configured the Linux user and cloned **Linux candidate
   `6dc45a8`**, and completed the Linux host installer:
   **Ansible `ok=35 changed=9 failed=0`**. This included signed rootless
   Podman and the NVIDIA NemoClaw Hermes CLI **v0.0.145**.
3. The subsequent read-only Ansible verification failed because AIW incorrectly
   looked for `~/.nemoclaw/source/dist/build-identity.json`. NVIDIA's own
   v0.0.145 source-checkout install path uses
   `~/.local/share/aiw-nemoclaw/source/dist/build-identity.json`.
   This Linux Draft PR fixes all three AIW checks and adds an executable
   offline regression for accepted, mismatched and missing build identity.
   The vendor installer itself succeeded; do not reinstall the WSL to fix
   an AIW verification bug.
4. The paired Windows Draft PR #85 adds a **bounded interrupted-install
   resume**: only clean, correct-origin checkouts at the exact previously
   reviewed candidate may advance to the newly pinned commit. A successful
   read-only `verify` reuses the existing Podman/NemoClaw installation
   and finishes user-local `aiw` registration; a failed verification
   does **not** trigger an automatic vendor reinstall.

These are **source and log-based observations**, not claims of successful
Hermes onboarding, sandbox lifecycle, or Windows reboot recovery of the new
instance. The new installation is not accepted until owner-driven verification
and a separate NVIDIA onboarding/Hermes sandbox test succeed.

### After host installation

Use the new penguin/Linux `aiw` menu to inspect gateway and explicitly
onboard Hermes. Verify provider/model completion, sandbox lifecycle and
workspace persistence on the **new** instance. Preserve old data and
keep separate explicit acceptance for replacement or deletion. Do not
make Windows restart a routine install requirement.

## Only after acceptance: separate retirement decisions

- Ask for exact distro-by-name confirmation and approval **before** any
  `wsl --unregister`, which irrevocably deletes the named root filesystem.
- Retire old `AIW-Nemo` as a **whole distro**, not by tampering with
  `testhermes02` records or Podman storage.
- Audit historical files in the **misnamed** `Ubuntu-26.04` separately
  before considering its retirement. Never infer it is disposable.
- Keep `Ubuntu-24.04` untouched. Move the Windows launcher and immutable
  Linux commit pin in a separately accepted Windows PR (#85), after Linux merge.
