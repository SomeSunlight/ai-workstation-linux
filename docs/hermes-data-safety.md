# Hermes data inventory, independent backup and restore gate (#78)

**Applies to:** the owner's existing `AIW-Nemo` Ubuntu 26.04 distro,
rootless Podman, upstream NemoClaw v0.0.144, sandbox `testhermes01`.
This is not an instruction to reinstall Hermes or replace the sandbox.
The newly installed `Ubuntu-26.04` is a separate **host installer test**,
not a replacement for `AIW-Nemo`.

**Current state:** owner-confirmed `Hermes Agent: running`. Host
installation and read-only verification passed on both the existing and
the new WSL host. An independent restorable *Hermes data* backup has
**not yet been demonstrated**; neither stop/start nor restore is accepted.

## 1. Read-only inventory — first owner test, while Hermes runs

Start a **separate** terminal from Windows PowerShell:

```powershell
wsl -d AIW-Nemo --user moresunlight
```

Inside that Linux host (NOT the fresh `Ubuntu-26.04`):

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes testhermes01 status
nemohermes testhermes01 connect
```

The last command opens a shell **inside** `testhermes01`. Do not type
host `sudo`, Podman or Git commands there. In that sandbox shell,
run **only this read-only existence inventory**:

```sh
for name in SOUL.md state.db kanban.db profiles platforms kanban; do
  path="/sandbox/.hermes/$name"
  if [ -f "$path" ]; then
    printf 'FILE     %s\n' "$name"
  elif [ -d "$path" ]; then
    printf 'DIRECTORY %s\n' "$name"
  else
    printf 'ABSENT   %s\n' "$name"
  fi
done
exit
```

Share only the six `FILE/DIRECTORY/ABSENT` lines (and whether
`connect` worked). If it errors, report **a redacted short error**.
Do not post `config.yaml`, `.env`, registry JSON, content of SQLite
databases, chat histories, token values, private hostnames or full logs.
This proves only that paths exist, **not** that they are consistent,
complete, backed up or recoverable. It does not stop Hermes.

## Owner inventory acceptance and inference-host restart (2026-11-19)

- An unexpected Windows Update reboot of the separate inference host
  left its services stopped. From `AIW-Nemo`, an unauthenticated HTTPS
  `/v1/models` probe returned `HTTP 000` / connection refusal.
  After the operator explicitly restarted **Speedy's existing services**,
  the same probe returned `HTTP 401` (HTTPS endpoint reachable, token
  required). This is **not** proof of authenticated model inference.
- `nemohermes testhermes01 connect` then **succeeded** without NemoClaw
  `recover`, onboarding, restart or a change to the recorded route.
  Before the inference host was restored, `connect` refused a route whose
  in-sandbox health probe was untrusted: `curl_exit=56`. Do not treat
  that refusal as proof that Hermes state or the OpenShell gateway
  was lost.
- The operator successfully executed the read-only inventory inside
  `testhermes01`: `SOUL.md`, `state.db`, `kanban.db` are **files**;
  `profiles/`, `platforms/`, `kanban/` are **directories**.
  All six exist; no contents or credential material were inspected.
- **Not yet achieved:** no independent state backup, file-copy trial,
  consistency check or restore validation; no lifecycle interruption.
  Windows Update handling is a dependency of the *external inference
  service*, not a reason to rebuild the Linux sandbox.

## First optional copy test: one non-database file, no sandbox stop

After the inventory gate, the next low-risk acceptance test is to
exercise the pinned vendor's **manual host download** against only the
known existing `SOUL.md`. Run from an `AIW-Nemo` *host shell*, **not**
inside the sandbox. This creates a private host file and does not
stop or replace the running sandbox:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
umask 077
BACKUP_DIR="$HOME/hermes-private-backups/soul-copy-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 -p "$BACKUP_DIR"
nemohermes testhermes01 download /sandbox/.hermes/SOUL.md "$BACKUP_DIR/"
if [ -s "$BACKUP_DIR/SOUL.md" ]; then
  printf 'SOUL.md: private host copy present (nonempty)\n'
else
  printf 'SOUL.md: missing or empty host copy; inspect download result\n' >&2
fi
```

The user should share **only** the vendor success/error and presence
indicator, never the file, its contents, host paths or other artifacts.
The file is potentially sensitive. This is a **single-file transfer
check only**; it is not a state.db consistency test, complete backup,
off-distro disaster recovery copy or functional restore proof.
Do not attempt to copy a live SQLite database at this stage.

## 2. Scope the backup before any lifecycle change

NVIDIA's exact pinned NemoClaw source documents that native
`/sandbox/.hermes/` contains the main Hermes DB, persona, kanban
state, profiles, platform sessions and other runtime data. OpenShell
owns **native home/workspace persistence** across normal stop/start.
Host-side `~/.nemoclaw/` includes the sandbox registry
`sandboxes.json`, host configuration and possible credentials.
Host-only OpenShell provider bindings/secret stores are a **separate
authority**; a file copy cannot establish their restorable state.

Do **not** run `nemohermes backup-all` expecting a general snapshot
create/list/restore API: the vendor explicitly labels it an
installer/upgrade safety operation without a general user-facing
restore contract. Do **not** use `rebuild` to create a backup: rebuild
can replace the live sandbox and has its own dependency/credential
checks. No direct Podman-volume copy or `wsl --export` is an accepted
substitute for a tested Hermes restoration.

Treat all backup files as **sensitive**, even if the filename looks
benign (state.db, platform sessions, named profiles). Choose a private
backup storage location outside source control and later a separately
protected destination outside the WSL distro. Do not upload raw state
into GitHub, a public issue, or this chat.

## 3. Targeted independent host download — future approved step

Only after the inventory is reviewed and a safe interruption window
is agreed, exit active Hermes sessions and **stop only**
`testhermes01` via the existing menu or
`nemohermes testhermes01 stop`. Check status reports `Stopped`;
other states are not permission to continue. For SQLite state.db
(or kanban.db), take the file copy when no Hermes writer is active.
If NemoClaw cannot download from a stopped sandbox, **stop** and
re-evaluate; do not start/rebuild/destroy automatically.

The vendor's documented download command is
`nemohermes <sandbox> download <sandbox-path> <host-dest>`. It
rejects unsafe symlink/special-file sources and verifies the
published host artifact. Once the stop gate has passed, select
**only the files observed to exist**:

```bash
umask 077
SANDBOX=testhermes01
BACKUP_DIR="$HOME/hermes-private-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 -p "$BACKUP_DIR"
# Examples — run ONLY for validated existing files, after approved stop:
nemohermes "$SANDBOX" download /sandbox/.hermes/SOUL.md "$BACKUP_DIR/"
nemohermes "$SANDBOX" download /sandbox/.hermes/state.db "$BACKUP_DIR/"
# Other optional content to review one by one: kanban.db, kanban/,
# profiles/, platforms/; these can include highly sensitive state.
```

Do not copy `/sandbox/.hermes/.env` or
`/sandbox/.hermes/config.yaml` **between sandboxes**: NVIDIA says
the receiving sandbox must obtain fresh managed credentials/routes.
Do not blindly archive the whole `.hermes` tree, because raw files
may contain agent/device secrets. If the authoritative state spans
additional paths under `/sandbox`, list them and design a separate
reviewed transfer: this targeted copy is **not a complete image**.

Check saved files exist and are nonempty; calculate SHA-256 checksums
locally without printing contents, record which optional resources
were excluded, and store the backup on encrypted media **outside the
WSL distro**. Verify the copied bytes again at the destination. A
hash comparison establishes transfer integrity, *not* functional
restorability. Take host registry/config backup separately under the
appropriate local credential-handling policy; do not paste or
check it into Git.

## 4. Restore proof and lifecycle gates — explicitly not yet passed

1. Verify local backup completeness, permissions, hashes, and
   an independently stored recoverable copy.
2. Plan a **separate new sandbox identity** for a manual restore test.
   Do not upload saved `config.yaml`/`.env` or overwrite live
   `testhermes01`. Fresh OpenShell provider bindings are needed.
3. Restore selected *non-generated* files using upstream
   `nemohermes <new-name> upload`, after review of each destination
   and applicable platform-/provider-state semantics. Prove the
   expected Hermes behavior, persistence across a stop/start, and
   absence of configuration/credential violations.
4. Only then mark the backup **restorable**. A targeted transfer cannot
   guarantee complete sandbox replacement without additional review
   of the complete native home and host-only authorities.
5. After owner acceptance, test normal existing-sandbox
   `status → stop → status → start → launch`, then WSL/Windows
   restart, then explicitly scoped crash recovery.
6. The Linux PR and Windows production handoff remain separate review
   and merge decisions; no implicit change to the desktop penguin.

## Upstream sources (pinned to the installed NemoClaw checkout)

- [Hermes state and storage](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/manage-sandboxes/workspace-files.mdx)
- [Manual Hermes state transfer](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/manage-sandboxes/transfer-state-manually.mdx)
- [Complete home persistence and backup-all limits](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/manage-sandboxes/backup-restore.mdx)
- [Host registry and credential-sensitive files](https://github.com/NVIDIA/NemoClaw/blob/82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f/docs/reference/host-files-and-state.mdx)
