# Safe cutover from the combined AI Workstation (#78)

> **Current status (2026-11-22):** Linux extraction PR #1 and Windows
> penguin launcher PR #84 are **merged**. Linux operator PR #5 and the
> independent pinned Windows cutover PR #85 remain **draft** until
> owner approval. Cloning is safe; installing, re-onboarding,
> deleting the old checkout, rebuilding, destroying or migrating a live
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
cd ~/ai-workstation-linux
git status --short --branch
git rev-parse --short HEAD
```

The owner already has a working independent Linux checkout.
Inspect `git status` and the active branch before switching. For a
**fresh host** that does not yet have this checkout, the initial
non-disruptive read-only trial would be:

```bash
cd ~
git clone https://github.com/SomeSunlight/ai-workstation-linux.git ai-workstation-linux
cd ai-workstation-linux
# Use the merged default branch; do not assume the old extraction branch exists.
./install.sh --version
./install.sh status
./install.sh verify
```

The status and verify commands are read-only and may report unmet
requirements on a new host; that is useful evidence, not an instruction
to reinstall. For the current operator candidate, select
`feat/4-hermes-operator-cockpit` only deliberately after checking the
local working tree; **after merge, use the new main commit**, not a stale
feature branch. If the existing NemoClaw installation uses
a different vendor revision, preserve it and report the mismatch.
Do not alter provider inference routes or onboard just to 'fix' a check.

## Acceptance gates and current results

1. CI green in the **new Linux repository** on the exact PR head
   (**required again after final PR #5 documentation changes**).
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
7. **Passed:** the owner qualified normal sandbox, gateway and WSL
   restarts, then diagnosed the full Windows reboot failure and
   demonstrated manual address preparation before starting the new
   `testhermes03` sandbox. The **same Hermes session resumed** after
   full Windows reboot. This is *manual, consented repair*, not an
   automatic vendor boot fix; crash/corruption stress testing remains
   optional and separately scoped.
8. Owner approves/squash-merges Linux PR #5, then separately
   qualifies the pinned Windows [PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85),
   and **only last** removes obsolete Linux copies from Windows.
   Merged Windows PR #84 supplies the penguin shell entry points but
   does not substitute for PR #85's source pin.

Historical safety details and known recovery problems remain in
[Issue #83](https://github.com/SomeSunlight/ai-workstation/issues/83)
and the
[recovery runbook](https://github.com/SomeSunlight/ai-workstation/blob/fix/83-nemohermes-recovery-launcher/docs/nemoclaw-recovery.md).
The overall split is tracked in
[Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
