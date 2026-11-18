# AI Workstation Linux

Portable Ubuntu agent workstation: rootless Podman and the upstream NVIDIA NemoClaw / OpenShell / Hermes stack, managed through a small Linux-native operator CLI.

This repository is **independent** of [AI Workstation for Windows](https://github.com/SomeSunlight/ai-workstation). It is designed to run on native Ubuntu or Ubuntu under WSL, without PowerShell or Windows service dependencies. Windows may select and launch a **pinned, reviewed Git revision** of this project but does not manage its sandbox lifecycle.

> **Migration in progress.** The Linux code is being extracted from the original combined repository under [Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78). A running WSL distribution, NemoClaw installation and existing Hermes sandbox are **not** modified merely by cloning this repository. Do not run an installer, onboarding, rebuild or destroy during this source migration.

See [the migration contract](https://github.com/SomeSunlight/ai-workstation/blob/feat/78-linux-project-handoff/docs/linux-repository-handoff.md) and [the existing Hermes recovery notes](https://github.com/SomeSunlight/ai-workstation/blob/fix/83-nemohermes-recovery-launcher/docs/nemoclaw-recovery.md) while the two projects are being separated.
