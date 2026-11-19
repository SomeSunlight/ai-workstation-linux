# Hermes backup and transfer — use the official tool (#78)

**Applies to:** existing `AIW-Nemo` WSL distro, rootless Podman,
NemoClaw/OpenShell, sandbox `testhermes01`. The clean-room
`Ubuntu-26.04` is a separate **host installer** test, not a Hermes
restore target yet.

## Architecture decision: prefer Hermes built-in backup

**Use the NousResearch Hermes application-level backup**, not a
custom AIW SQLite snapshot engine or hand-maintained file inventory.

- `hermes backup` creates a zip of the Hermes home: user profiles,
  persona, memory, skills, conversations, schedules, configuration,
  and credentials (including `.env` and `auth.json`). It uses the
  SQLite **online backup API** and omits transient WAL/journal files.
  A full backup exits successfully only when selected files were
  captured; an incomplete archive is reported as an error.
- `hermes import <zip>` restores Hermes application state. **Import
  overwrites target files**, so it is not an ordinary restart command
  and must not be run on the currently working `testhermes01`.
- The separate **NemoClaw** command `nemohermes backup-all`
  is an *installer-upgrade safety mechanism*, not the Hermes
  application's supported user-data export and import.
- A Hermes zip does **not** replace OpenShell's host-side sandbox
  registry, container/volume authority, policies and credential
  provider bindings. In particular, a raw restored `.env` or
  `config.yaml` may conflict with the managed inference route on
  another sandbox. Review the vendor-supported destination procedure
  before any import. The cloud-specific `--keep-host` option is not
  a license to overwrite a NemoClaw-managed sandbox without testing.
- The Hermes backup may include **API keys, logins and messaging
  tokens**. Treat an ordinary zip as sensitive plaintext even if it
  contains no obvious secret in its filename. Store it privately on
  the Linux host until encrypted; transfer only encrypted copies
  outside WSL, never into Git, chat attachments or a synchronized
  Windows directory in plaintext.

This replaces the previously proposed manually constructed
`state.db`/`kanban.db` snapshots and the three-file GPG/tar
archive **as the normal backup workflow**. Do not run those obsolete
steps. GPG may still be useful to encrypt the **single official Hermes
backup zip** for external storage; AIW need not implement its own
archiver.

## Next owner acceptance: check installed Hermes command, read-only

In Windows PowerShell open the **existing** environment:

```powershell
wsl -d AIW-Nemo --user moresunlight
```

Then in the `AIW-Nemo` **host** shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes testhermes01 connect
```

Inside `testhermes01` (sandbox prompt), run only:

```bash
command -v hermes
hermes --version
hermes backup --help
```

Then `exit` to return to the host. This checks whether the
**installed** Hermes image supports the upstream command; the
current website may describe a newer Hermes than the pinned NemoClaw
image. Share only the version and the relevant backup help/flags,
**not credentials or config contents**. If `hermes backup` is missing,
do not update Hermes inside the managed sandbox on your own. Review
the image version/pin and upstream-managed upgrade compatibility first.

## After command support is confirmed (NOT YET EXECUTED)

1. From the sandbox, use `hermes backup -o <private-path>.zip` for a
   **full** archive. Do not select `--quick` for a migration-grade
   user-data backup, and check the exit code/any incomplete notices.
2. Download the completed zip using NemoClaw's supported
   `nemohermes <sandbox> download <sandbox-path> <private-host-dest>`.
   Copy it only to a private directory owned by the Linux user.
3. Encrypt the resulting official zip before exporting it from
   `AIW-Nemo`. Check encrypted-file readability; retain the
   decryption secret separately in a password manager.
4. In a separately approved test sandbox, assess import semantics
   against **NemoClaw-managed** route and gateway ownership and test
   the intended user-state restoration. Until then a zip existing on
   Windows is **not proof of application-level restorability**.
5. Only after those checks can we qualify normal sandbox stop/start,
   WSL restart and deliberate Windows/Dispatcher recovery.

**Do not invoke `hermes import` or `nemohermes rebuild` as a
backup verification on the working sandbox.** No new backup
scheduler/service/registry is justified in AIW.

## Previous operator field checks (superseded as backup design)

- The existing `testhermes01` has files `SOUL.md`, `state.db`,
  `kanban.db` and directories `profiles/`, `platforms/`,
  `kanban/`.
- Downloading `SOUL.md` from the running sandbox to the private WSL
  host succeeded.
- Python SQLite 3.46.1 provided `Connection.backup`; two
  independently verified SQLite snapshots passed `PRAGMA quick_check`
  and were downloaded to the WSL host. This was a correct technical
  experiment but **not a full Hermes backup**. Keep existing artifacts
  for now; they do not need to become an AIW product feature.
- An unexpected Windows Update reboot of external Speedy left the
  inference services unavailable. The HTTPS probe returned 000;
  after operator restarted services it returned 401 (auth enforced),
  and `testhermes01 connect` succeeded without any NemoClaw repair.
  That was a Windows service dependency, not a sandbox state loss.

## Authoritative sources

- [NousResearch: Backup & Transfer](https://hermes-agent.nousresearch.com/docs/user-guide/backup-and-transfer)
- [Hermes CLI: backup and import](https://hermes-agent.nousresearch.com/docs/reference/cli-commands#hermes-backup)
- [Pinned NemoClaw: persisted sandbox home vs host authorities](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/manage-sandboxes/backup-restore.mdx)
- [Pinned NemoClaw: Hermes state paths](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/manage-sandboxes/workspace-files.mdx)
