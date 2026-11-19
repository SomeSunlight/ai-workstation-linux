# Linux extraction plan — Issue #78

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
- [ ] Document a verified restorable backup and perform owner-approved migration or optional clean Hermes onboarding.
- [x] Windows Draft PR #85 contains a candidate SHA pin and *opt-in read-only* version/status/verify adapter; offline Windows CI green. The production shortcut/installer cutover is still pending.
- [ ] After owner approval, update Windows candidate pin to the **merged** Linux commit and switch the production bootstrap/shortcut via a separate tested cutover.
- [ ] Owner-approved merges and retirement of the original monolithic Linux code.
