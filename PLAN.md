# Linux extraction plan — Issue #78

- [x] Repository initialized; development proceeds in a draft PR, never in deployed WSL.
- [x] Linux-owned NemoClaw/Podman roles and vendor commit pins extracted.
- [x] Monolithic Windows/Goose CLI calls removed from Linux bootstrap.
- [x] Dedicated source-level Linux CI and safe read-only CLI added.
- [x] Exact-head Linux CI green (source/CLI, pinned uv lock, Ansible lint and playbook syntax; run #11 on da4c1cc).
- [x] Prepare ContextCanon upstream mapping and exact first-adoption instructions in `docs/contextcanon-setup.md` without fabricating generated artifacts.
- [ ] Execute official ContextCanon `build` → `source adopt` → `build` → `check` on a separate development checkout, then review/commit generated outputs and add a pinned read-only CI check.
- [ ] Qualify actual `install` on a **clean disposable** Ubuntu 26.04 host (native Linux preferable); current CI checks only the Ansible graph and operator contract.
- [x] Owner read-only side-by-side AIW-Nemo test: `./install.sh --version`, `status`, `verify`; reported `[OK] Independent Ubuntu/Podman/NemoClaw verification passed.` (2026-11-18). Existing `testhermes01` was not intentionally changed.
- [ ] Document a verified restorable backup and perform owner-approved migration or optional clean Hermes onboarding.
- [x] Windows Draft PR #85 contains a candidate SHA pin and *opt-in read-only* version/status/verify adapter; offline Windows CI green. The production shortcut/installer cutover is still pending.
- [ ] After owner approval, update Windows candidate pin to the **merged** Linux commit and switch the production bootstrap/shortcut via a separate tested cutover.
- [ ] Owner-approved merges and retirement of the original monolithic Linux code.
