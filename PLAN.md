# AI Workstation Linux — development and acceptance plan

## 2026-11-25 — temporary Error recovery (#11 / PR #12)

- [x] Confirm pinned OpenShell 0.0.116 and independent upstream phase-only precedent (#3440).
- [x] Implement explicit offline repair of a single sandbox phase; no automatic backups, policy edits or runtime replacement.
- [x] Owner live test: testhermes04 was already Stopped; native start, chat and stop passed without repair.
- [x] Owner live test: testhermes05 Error with MainProcessExited; repair -> Stopped -> native start -> Ready; Hermes chat and WhatsApp replies work, pairing retained.
- [x] Owner live test: subsequent normal stop/start and autonomous WhatsApp communication passed (2026-11-25).
- [x] Record premature NemoClaw startup probe and unknown WhatsApp diagnostics despite working service; do not rebuild on this evidence.
- [ ] Final exact-head CI, owner squash-merge and post-merge baseline checkpoint.
- [ ] Remove emergency helper when NemoClaw pins a release with adequate native Error recovery. No new recovery infrastructure.
- [ ] Separate follow-up PR #10: post-onboarding WhatsApp reminder; fresh wizard display not yet owner-tested. PR #9: private-host consent; separate acceptance.

## Live acceptance and merge handoff (2026-11-23)

**Fresh deployment: owner ACCEPTED.** Windows AIW Draft PR #85 installed
**only** `AIW-Nemo-New` with actual Ubuntu 26.04, rootless Podman,
official NVIDIA NemoClaw v0.0.145 and OpenShell 0.0.116.
The corrected Linux verifier passed, and `aiw` was registered.
After a first-run NVIDIA preflight was blocked by an omitted `--no-gpu`
in the *Windows* launcher, Windows now invokes this Linux project's
pre-existing CPU-only `aiw-nemo onboard` instead. NVIDIA resume needed
the explicit sandbox name because the original failed before creating
sandbox identity; owner successfully completed onboarding as
`testhermes04`, with working Hermes and OpenRouter inference.

**Full Windows reboot while `testhermes04` was running: PASS with
explicit manual network repair.** The same sandbox survived as `Stopped`
with its workspace preserved; user systemd OpenShell gateway remained
active and Podman socket available. The vendor-required
`169.254.2.2/32` loopback alias was missing after reboot *again*,
including with NemoClaw v0.0.145. AIW's guarded, consented host-address
preparation allowed the existing sandbox to start; owner confirmed Hermes
returned to service and produced a new model-based answer. This validates
the no-prior-stop Windows reboot case on this host, **not** abrupt WSL
power-loss/corruption recovery, automatic boot repair or the old
`Error` sandboxes' restoration.

**Release order:** first owner squash-merges
[Linux PR #7](https://github.com/SomeSunlight/ai-workstation-linux/pull/7)
after exact-head green CI. Obtain the resulting Linux `main` squash
SHA, then repin the Windows manifest in
[Windows PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85),
run exact-head Windows CI, and only then squash-merge Windows.
Protect `Ubuntu-24.04`, misnamed `Ubuntu-26.04`, and `AIW-Nemo`;
no distro cleanup, provider migration, sandbox rebuild, or forced update
is part of these merges. Native bare-metal Ubuntu is still untested.

**Separated follow-ups:** [Issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3)
is the evidence base for a short, factual NVIDIA NemoClaw upstream bug
report and focused regression, to be researched and drafted in a separate
conversation; do not publish without owner approval. [Issue #2](https://github.com/SomeSunlight/ai-workstation-linux/issues/2)
tracks improving actual agent capabilities, including controlled web
access and browser/HTML preview. Sandbox proxy blocking arbitrary
external sites while OpenRouter inference works is expected isolation,
not an outage to bypass.

## Current checkpoint (2026-11-22)

**Baseline:** Linux extraction [PR #1](https://github.com/SomeSunlight/ai-workstation-linux/pull/1)
and the Windows penguin launcher [PR #84](https://github.com/SomeSunlight/ai-workstation/pull/84)
have been merged. The operator uses the real Linux `aiw` command from
`AIW-Nemo`; vendor lifecycle and policy remain owned by NemoClaw/OpenShell.

**Operator release:** [PR #5](https://github.com/SomeSunlight/ai-workstation-linux/pull/5)
addresses [Issue #4](https://github.com/SomeSunlight/ai-workstation-linux/issues/4)
and was owner-accepted and squash-merged into `main`.
Its Windows-reboot host-alias preparation **passed** with a new
`testhermes03` sandbox after a full Windows restart; the **same Hermes
session was resumed**. The later *consent-to-start a Stopped sandbox
when continuing a chat* has now also **passed owner-reported live testing** (2026-11-22).
No automatic Windows-start address restoration or already-`Error`
sandbox rescue is claimed.

**Next gate — Issue #6:** pin NVIDIA v0.0.145 at the verified annotated-tag
commit, qualify offline CI, then test a **new** Ubuntu 26.04 WSL distribution
side by side. Keep the old `AIW-Nemo` (including its stuck `testhermes02`)
untouched until the replacement works. Deletion requires a separate
identity check and explicit owner approval. Existing `Ubuntu-26.04` WSL
was inspected on 2026-11-22 and reports **Ubuntu 24.04** internally,
with historical files; it is **not** a fresh 26.04 installation candidate.
The productive `Ubuntu-24.04` WSL is excluded from all cleanups.
See [fresh qualification](docs/fresh-nemoclaw-wsl.md).

**After PR #5:** Focus on practical agent tooling
([Issue #2](https://github.com/SomeSunlight/ai-workstation-linux/issues/2));
a separately approved NemoClaw v0.0.145 upgrade; independent Windows
pinned handoff ([Draft PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85));
and a **separate** NVIDIA NemoClaw upstream issue/PR using the already
recorded [reproduction and successful workaround](https://github.com/SomeSunlight/ai-workstation-linux/issues/3).
The upstream work should verify the current vendor branch again before
editing, and keep OpenShell under NemoClaw version ownership.
Follow-up: Windows launcher revision warning and Hermes `tirith`
scanner not available (not to be hidden).

## Historical extraction milestones — Issue #78

- [x] Repository initialized; development proceeds in a draft PR, never in deployed WSL.
- [x] Linux-owned NemoClaw/Podman roles and vendor commit pins extracted.
- [x] Monolithic Windows/Goose CLI calls removed from Linux bootstrap.
- [x] Dedicated source-level Linux CI and safe read-only CLI added.
- [x] Exact-head Linux CI green (source/CLI, pinned uv lock, Ansible lint and playbook syntax; run #11 on da4c1cc).
- [x] Prepare ContextCanon upstream mapping and exact first-adoption instructions in `docs/contextcanon-setup.md` without fabricating generated artifacts.
- [x] Official ContextCanon 0.10.0 at `5a1f2bf`: `build → source adopt → build → check` passed on isolated GitHub Actions; immutable Development Workflow `0.3.9-draft` compiled into Linux context, generated files committed. CI now checks it read-only.
- [x] Correct uv 0.11.26 post-install pin check to parse the numeric version (uv may print extra build metadata); offline regression covers fresh install, repeat/no-redownload, and mismatch refusal. The owner then successfully resumed the installer on separate clean-room `Ubuntu-26.04` (2026-11-19).
- [x] Qualify actual `./install.sh install` on a **separate fresh WSL Ubuntu 26.04**: owner reports Ansible recap `ok=19 changed=0 unreachable=0 failed=0` and `[OK] Linux host installed; NemoClaw onboarding remains an explicit operator action.` (2026-11-19). Native bare-metal Ubuntu remains untested.
- [x] Owner final independent read-only `./install.sh verify` on the fresh `Ubuntu-26.04` WSL host **passed** (2026-11-19): `nemohermes v0.0.144` and `[OK] Independent Ubuntu/Podman/NemoClaw verification passed.` No Hermes sandbox onboarding in the test distro.
- [x] Owner read-only side-by-side AIW-Nemo test: `./install.sh --version`, `status`, `verify`; reported `[OK] Independent Ubuntu/Podman/NemoClaw verification passed.` (2026-11-18). Existing `testhermes01` was not intentionally changed.
- [x] Owner exercised Linux Hermes operator menu option 7 with numbered existing-sandbox selection and upstream status action on `AIW-Nemo`; reported `Hermes Agent: running` (2026-11-19). No stop/recover/rebuild was performed.
- [x] Review pinned NemoClaw native Hermes-state persistence/host registry and upstream manual download semantics; add `docs/hermes-data-safety.md` with non-mutating six-path inventory and explicit sensitive backup/restore gates (2026-11-19). No user data copied or lifecycle command executed.
- [x] Owner read-only on-sandbox inventory (2026-11-19): `SOUL.md`, `state.db`, `kanban.db` are files; `profiles/`, `platforms/`, `kanban/` directories; `testhermes01` connect succeeded after external Speedy services were restarted. No file contents copied or viewed.
- [x] Diagnose real Windows Update reboot of independent Speedy inference host: services absent → HTTPS HTTP 000, restarted → HTTP 401; NemoClaw in-sandbox route failed closed before host recovery, `connect` succeeded after. Recorded in `docs/nemoclaw-recovery.md` (HTTP 401 reachability ≠ authenticated inference success).
- [x] Owner ran pinned NemoClaw download of existing `testhermes01` `SOUL.md` and verified nonempty private file on AIW-Nemo host (2026-11-19). Sandbox was not stopped. This is **not** an off-distro copy or tested restore.
- [x] Owner verified Python SQLite 3.46.1, `sqlite3.Connection.backup` available and nonempty `state.db`/`kanban.db` inside existing `testhermes01`. Read-only capability check succeeded; no database content copied (2026-11-19).
- [x] Owner ran Python SQLite online backup of **both** `state.db` and `kanban.db` inside running `testhermes01`, with both `[OK] ... quick_check=ok` and no errors (2026-11-19). Each DB snapshot is independently consistent; snapshots still reside inside the sandbox.
- [x] Owner reports successful vendor download of the two verified SQLite snapshots to a private `AIW-Nemo` host directory after correcting a `SNAPSHOT_DIR` vs `BACKUP_DIR` substitution. Host-side verification script completed successfully (2026-11-19). No off-distro copy or actual restore yet.
- [x] Owner reports `gpg (GnuPG) 2.4.8`, `tar (GNU tar) 1.35`, and accessible `/mnt/c` from `AIW-Nemo`; encrypted off-distro prerequisites verified (2026-11-20).
- [x] Architecture corrected following owner review (2026-11-20): **NousResearch Hermes already provides `hermes backup` / `hermes import`** for full agent state; our SQLite snapshots were technically valid but should not become a parallel AIW backup system. Superseded custom GPG/tar three-file backup instructions and replaced the runbook with official Hermes workflow and explicit NemoClaw host-authority caveats.
- [x] Owner ran `hermes backup --help` inside the existing `testhermes01` (2026-11-20): the installed Hermes CLI explicitly supports **full** ZIP backup, `--output`, `--quick`, and `--keep N` (`0` preserves all earlier backups). No backups or import were performed by this help command.
- [x] Owner completed official **full** `hermes backup --keep 0` inside running `testhermes01`: Hermes reported **2,824 files** and the restore hint `hermes import hermes-backup-2026-11-19-232806.zip` (reported 2026-11-20). No import or runtime change; archive remains private in the sandbox.
- [x] Owner confirms official full Hermes ZIP was downloaded into a private `AIW-Nemo` host directory and all ZIP entries passed independent CRC/readability verification (`[OK] Official Hermes ZIP copied; CRC verified.`) on 2026-11-20. No import or other sandbox mutation.
- [x] Owner confirms full official Hermes ZIP encrypted with installed GnuPG AES-256, and the decrypted byte-for-byte equality test succeeded; encrypted file stored on another Windows drive outside WSL (2026-11-20). The password is kept privately. This is application-data preservation; **restore/import not tested** and physical disk independence not established. No parallel AIW backup engine.
- [x] Unexpected Windows/WSL reboot exposed a concrete Hermes restart failure: the stopped `testhermes01` sandbox's existing Podman `ExtraHosts` retained `169.254.2.2`, but a fresh disposable container resolved `169.254.1.2`; TCP to port 8080 succeeded only on the latter. Sandbox logs: `Policy fetch failed after 5 attempts`; exited 1, OOM=false. External Speedy inference host still resolved correctly and returned 401. Reproduction is recorded in Windows Issue #83 and `docs/restart-qualification.md`.
- [x] Added Linux-native `aiw network` IP/route/bridge/Podman host-alias inventory to existing status and selected Hermes menus, restricted one-time JSON snapshot and before/after comparison; **no container startup on normal status**. Optional `--probe` uses a disposable cached-image no-mount container only when explicitly requested. Offline CI checks both paths.
- [x] Added user-only, collision-protected `./install.sh register-cli` for `~/.local/bin/aiw`; Windows [PR #84](https://github.com/SomeSunlight/ai-workstation/pull/84) has since **merged** and the owner successfully used its project penguin on the laptop to open WSL and AIW after a full Windows reboot.
- [x] **Priority 1, bounded source-level recovery assessment:** the real ordinary `start` failed; inspected installed OpenShell 0.0.116's upstream sandbox CLI enum and found **no documented host-alias rebind** or guaranteed data-preserving in-place recovery command. `podman update` does not support rewriting persisted `HostConfig.ExtraHosts`. **Consciously stop** here without speculative repair; old `testhermes01` remains unchanged. A live in-place recovery has **not** succeeded. Revisit only when newer vendor versions expose supported correction or before a separately approved destructive migration.
- [x] **Priority 2, essential Linux operator acceptance:** the owner invoked `aiw` through the penguin Linux shell, selected a registered sandbox by number, inspected gateway/host-IP state and continued a Hermes session after Windows reboot. No additional WSL instance, supervisor or automatic service management was introduced. The separate Windows pinned handoff remains pending.
- [x] **Priority 3, independent new sandbox:** the owner created and used `testhermes03` through official onboarding and preserved the two older `Error` sandboxes. **Not done and not required for this PR:** Hermes ZIP import, rehabilitation or deletion of `testhermes01`/`testhermes02`.
- [x] **Priority 4, scoped reboot qualification:** sandbox, gateway and WSL termination/restart gates passed; the original full Windows restart exposed the missing Podman callback alias. A subsequent full Windows restart **passed** with explicit NVIDIA-equivalent host-IP repair *before* starting `testhermes03`; native Hermes conversation persisted. An automatic reboot-time vendor fix is still outstanding.
- [ ] **Primary product value** after basic agent access: [Linux Issue #2](https://github.com/SomeSunlight/ai-workstation-linux/issues/2) captures an actual local Strata/Hermes technical task, secure browser/HTML5 visual preview, and minimal trusted toolchain; prior offline Canvas harness worked, browser-based preview was unavailable (Chromium/Playwright download 403). Do not block it on full WSL/Windows reboot certification. See `docs/restart-qualification.md`.
- [x] Windows [Draft PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85) contains an *opt-in read-only* pinned version/status/verify adapter; it remains **open**, and the independent pinned production handoff is not merged. Windows PR #84 (penguin launcher) has merged.
- [ ] After Linux PR #5 is **approved and merged**, update the Windows [PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85) candidate pin to the **merged Linux commit** and qualify the remaining independent cutover. Do not infer a Linux version from a Windows branch.
- [ ] Owner-approved merges and retirement of the original monolithic Linux code.

## Post-Windows-restart operational UX — Issues #3 and #4

- [x] Capture four staged restart results: sandbox, gateway and WSL restarts passed; complete Windows reboot reproduced policy-fetch/host-IP failure.
- [x] Compare private read-only network snapshots: vendor Podman host aliases persisted at `169.254.2.2`; the loopback interface lost that address; gateway remained active.
- [x] Trace the exact pinned NVIDIA source: alias setup is part of effectful native-Podman host preparation but absent from the installed user-systemd gateway unit and normal existing-sandbox startup.
- [x] Save a sanitized, standalone evidence dossier in [Issue #3](https://github.com/SomeSunlight/ai-workstation-linux/issues/3), retaining uncertainty until a repaired Windows reboot succeeds.
- [x] Implement draft [Issue #4](https://github.com/SomeSunlight/ai-workstation-linux/issues/4) operator cockpit: multi-sandbox selection, conversation vs sandbox lifecycle, shared gateway status, fail-closed host-alias guard, consented NVIDIA-equivalent preparation and scoped Node warning suppression.
- [x] Owner's transparent smoke test returned `[OK] AIW cockpit` and exit code 0 after the hidden-input bug was corrected; source/CI validation has run successfully on the updated draft. The merge gate remains **final-head CI green**.
- [x] Owner live test (2026-11-21): new `testhermes03` sandbox, a persisted Hermes conversation, explicit sandbox stop, complete Windows reboot, missing host alias detected, approved sudo restoration, vendor start reached `Ready`, and the *same* Hermes session resumed. The log confirms a pre-restart agent answer; it does not independently show a newly generated post-restart answer.
- [x] Usability follow-up **accepted in live use (owner report, 2026-11-22)**: selecting `Continue most recent conversation` successfully resumes Hermes through the new menu. When the selected sandbox is `Stopped`, the code offers explicit consent to start it, reuses the preflight and verifies `Ready`. Smoke tests also cover approval/decline and unsafe phases; no silent startup.
- [ ] Separately approve and qualify NemoClaw v0.0.144 → v0.0.145 (or a re-verified newer release) upgrade. The Linux installer checks exact pins and is **not an in-place upgrade command**; review any vendor backup/cleanup impact on older Error-phase sandboxes. Do not silently change the pin.
- [ ] After live acceptance, prepare an NVIDIA **NemoClaw** (not OpenClaw) issue or PR and a narrow before/after regression test in a separate conversation.

## Squash-merge checklist — Draft PR #5

- [x] Vendor root-cause review and sanitized evidence captured in Issue #3.
- [x] Real `testhermes03` cold Windows-restart recovery and preserved Hermes conversation observed.
- [x] New menu/safety contracts covered by transparent offline smoke tests (including consent to start a Stopped sandbox).
- [x] Owner reports **successful live test of `Continue most recent conversation`** after the final UX improvement (2026-11-22); remaining operator acceptance gap closed.
- [x] Operator/README/restart instructions updated to distinguish old incident from successful manual recovery.
- [x] PR #5 **exact-head** CI green after documentation reconciliation (both Linux source/operator and Ansible-contract jobs; revalidate the very final commit in the PR checks).
- [x] Owner accepted PR #5 and squash-merged it into main (2026-11-22).
- [ ] Post-merge: verify `main` revision and handoff the Windows pin only through the separate Windows draft PR.
