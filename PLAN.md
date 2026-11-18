# Linux extraction plan — Issue #78

- [x] Repository initialized; development proceeds in a draft PR, never in deployed WSL.
- [x] Linux-owned NemoClaw/Podman roles and vendor commit pins extracted.
- [x] Monolithic Windows/Goose CLI calls removed from Linux bootstrap.
- [x] Dedicated source-level Linux CI and safe read-only CLI added.
- [ ] Exact-head CI green; fix only verified failures.
- [ ] Complete ContextCanon Development Workflow import using official source/adopt/update/build; inspect generated drift and write separate context PR if appropriate.
- [ ] Run an independent clean Ubuntu 26.04 install/verify and rootless Podman qualification.
- [ ] Owner read-only side-by-side AIW-Nemo test; protect existing Hermes files, credentials, and sandbox.
- [ ] Document a verified restorable backup and perform owner-approved migration or optional clean Hermes onboarding.
- [ ] Windows PR pins the exact Linux commit and invokes stable Linux contract; no WSL automatic update.
- [ ] Owner-approved merges and retirement of the original monolithic Linux code.
