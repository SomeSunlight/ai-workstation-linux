# Safe cutover from the combined AI Workstation (#78)

> **Draft migration gate.** Cloning is safe; installing, re-onboarding,
> deleting the old checkout, rebuilding, destroying and migrating a live
> sandbox are **not** implied by clone or by this documentation.

## Why the split matters

The previous Windows checkout and `AIW-Nemo` Linux checkout were separate
Git trees even when they shared one repository name. Pulling a Windows
branch and repairing the penguin shortcut did not update Linux's menu.
The current design makes Linux its own project and release, with
independent code provenance and CI; Windows will ultimately pin a
**reviewed immutable 40-character Linux commit SHA**.

## Non-disruptive owner trial

In an ordinary PowerShell prompt (Windows is only the terminal launcher):

```powershell
wsl -d AIW-Nemo --user moresunlight
```

Inside Linux, **outside any sandbox**:

```bash
cd ~/ai-workstation
git status --short --branch
git rev-parse --short HEAD
```

Inspect that state before changing any Git branch. Do not pull the old
working checkout merely to test this migration. To test the new source
side by side **without any installation**, create a different directory:

```bash
cd ~
git clone https://github.com/SomeSunlight/ai-workstation-linux.git ai-workstation-linux
cd ai-workstation-linux
git switch feat/78-linux-bootstrap-extraction
./install.sh --version
./install.sh status
./install.sh verify
```

The last two commands are read-only and may report unmet expectations
while the candidate remains unqualified; that is useful evidence, not
an instruction to reinstall. If the existing NemoClaw installation uses
a different vendor revision, preserve it and report the mismatch.
Do not alter provider inference routes or onboard just to 'fix' a check.

## Acceptance gates

1. CI green in the **new Linux repository** on the exact PR head.
2. Independent code review: Linux paths have no Windows/WSL API
   requirements and Linux installation has no dependence on monolithic
   `bin/aiw` or Docker/Goose services.
3. Read-only status and verification on the owner's existing AIW-Nemo
   distribution, without changing `testhermes01`.
4. Document/verify recoverable backup of user-owned Hermes artifacts,
   working files and current upstream configuration; keep secrets
   outside public Git and logs.
5. Clean-room Ubuntu 26.04 + rootless Podman + upstream NemoClaw
   installation; optional Hermes **new** sandbox only with operator
   approval. No automatic destruction of `testhermes01`.
6. A separate reviewed Windows PR changes its bootstrap from the
   monolithic Linux directory to a pinned new Linux artifact.
   Windows must print the selected Linux revision and must not
   infer it from its own branch or auto-fetch at launcher startup.
7. Controlled lifecycle and WSL/Windows restart recovery, followed by
   explicitly scoped crash testing; preserve other WSL installations.
8. Owner approves the Linux merge, then the independent Windows
   cutover, and **only last** removes obsolete Linux copies from Windows.

Historical safety details and known recovery problems remain in
[Issue #83](https://github.com/SomeSunlight/ai-workstation/issues/83)
and the
[recovery runbook](https://github.com/SomeSunlight/ai-workstation/blob/fix/83-nemohermes-recovery-launcher/docs/nemoclaw-recovery.md).
The overall split is tracked in
[Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
