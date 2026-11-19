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

## Owner single-file transfer acceptance (2026-11-19)

The owner successfully ran the above **private host download** and the
nonempty-file check returned
`[OK] SOUL.md wurde privat auf den Linux-Host kopiert.`
The live sandbox was **not** stopped and no database was copied. This
confirms a host copy of one file only; it is **not yet off-distro** and
does not establish that the complete Hermes state is backed up.

## Next test: inspect SQLite snapshot capability, read-only

Connect to the existing `testhermes01` through the `AIW-Nemo` host
shell, not the separate fresh Ubuntu host:

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes testhermes01 connect
```

Inside the sandbox run:

```sh
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import sqlite3; print("Python SQLite:", sqlite3.sqlite_version); print("Online backup API:", "available" if hasattr(sqlite3.Connection, "backup") else "missing")'
else
  echo "Python SQLite: Python 3 not installed"
fi
for name in state.db kanban.db; do
  if [ -s "/sandbox/.hermes/$name" ]; then
    printf 'DATABASE %s: present, nonempty\n' "$name"
  else
    printf 'DATABASE %s: missing or empty\n' "$name"
  fi
done
exit
```

Share only the four summary lines, not files or SQL rows. This
only tests availability of Python's SQLite online-backup API and the
two source files; it neither reads private records nor creates a
snapshot. If Python/sqlite3 is absent, review alternate supported
methods before installing anything inside the sandbox. If the API
is present, a *future* snapshot operation should use SQLite's
transactionally consistent backup API with secure per-database output
and `PRAGMA quick_check` on the copy, **never a raw live `.db`
download**. Keep off-distro encrypted copy and separate restore
validation as later gates.

## Owner SQLite-capability acceptance (2026-11-19)

The owner verified **SQLite 3.46.1**, a present
`sqlite3.Connection.backup` API, and **nonempty**
`/sandbox/.hermes/state.db` and `kanban.db` in the existing live
sandbox. The capability test was read-only. No database snapshots
or restoration have yet been attempted.

## Next owner test: protected, online per-database snapshots

**This step writes new private snapshot files inside the sandbox.**
It does **not** write the originals, stop Hermes, touch host/Windows
credentials, or replace the sandbox. In a host shell of `AIW-Nemo`,
connect to `testhermes01`; inside its shell run:

```bash
python3 - <<'PY'
import os
import sqlite3
import tempfile
from pathlib import Path

os.umask(0o077)
base = Path("/sandbox/.hermes")
stage = Path(tempfile.mkdtemp(prefix=".aiw-hermes-sqlite-", dir="/sandbox"))
print(f"SNAPSHOT_DIR={stage}")

for name in ("state.db", "kanban.db"):
    source = base / name
    if not source.is_file() or source.stat().st_size == 0:
        raise SystemExit(f"[FAIL] {name}: missing or empty")

    original = sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=30)
    copy = sqlite3.connect(stage / name, timeout=30)
    try:
        original.backup(copy, pages=256, sleep=0.25)
    finally:
        copy.close()
        original.close()

    snapshot = stage / name
    verify = sqlite3.connect(snapshot.as_uri() + "?mode=ro", uri=True)
    try:
        result = verify.execute("PRAGMA quick_check").fetchone()
    finally:
        verify.close()
    if result != ("ok",) or snapshot.stat().st_size == 0:
        raise SystemExit(f"[FAIL] {name}: SQLite snapshot check failed")
    print(f"[OK] {name}: private snapshot; quick_check=ok")
PY
```

Then leave the sandbox with `exit`. If the command errors, do not
copy or rename the incomplete stage: report only sanitized failure
status, without database content or a private path. The timestamp-
independent, random `SNAPSHOT_DIR` value is needed for the **next**
explicit host download test; keep it locally. The new staging
directory has restrictive permissions; no shell `umask` assumptions.

This uses Python's documented SQLite online backup API, which
works during concurrent access, instead of downloading an actively
written `.db` file. Each database is backed up independently; **not
a cross-database atomic snapshot**. `PRAGMA quick_check` tests
individual SQLite file integrity but does not prove Hermes application
behavior, transaction correlation, complete native-home state, or
actual restore. These files may contain sensitive records and must
never be attached to issues, chat, or the repository. They remain
inside the same sandbox until separately downloaded and protected
outside the WSL distro.

Reference: [Python sqlite3.Connection.backup](https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.backup).

## Owner snapshot acceptance (2026-11-19)

The owner ran the in-sandbox Python SQLite online backup and confirmed
**both** `[OK]` results without errors:
`state.db: private snapshot; quick_check=ok` and
`kanban.db: private snapshot; quick_check=ok`. This validates two
distinct transactionally consistent snapshot files **inside the existing
sandbox**. It does **not** mean the copies were exported or persisted
outside the WSL distribution, and it does not prove a complete Hermes
restore.

## Next owner test: host-download and independent SQLite integrity checks

From the `AIW-Nemo` **host**, not the connected sandbox, use the actual
`SNAPSHOT_DIR` printed by the preceding Python command. Substitute
**only** that string (never copy the source DB path). It must start with
`/sandbox/.aiw-hermes-sqlite-`. Stop if the path is not known; do not
guess or automatically select the newest directory.

```bash
(
  set -euo pipefail
  export PATH="$HOME/.local/bin:$PATH"
  export NEMOCLAW_GATEWAY_RUNTIME=podman
  umask 077

  SNAPSHOT_DIR='/sandbox/.aiw-hermes-sqlite-REPLACE_WITH_ACTUAL_SUFFIX'
  [[ "$SNAPSHOT_DIR" == /sandbox/.aiw-hermes-sqlite-* ]] ||
    { printf '[FAIL] Invalid snapshot directory\n' >&2; exit 1; }
  [[ "$SNAPSHOT_DIR" != *REPLACE_WITH_ACTUAL_SUFFIX* ]] ||
    { printf '[FAIL] Set the actual SNAPSHOT_DIR first\n' >&2; exit 1; }

  install -d -m 700 "$HOME/hermes-private-backups"
  BACKUP_DIR="$(mktemp -d "$HOME/hermes-private-backups/sqlite-XXXXXXXX")"

  for name in state.db kanban.db; do
    nemohermes testhermes01 download "$SNAPSHOT_DIR/$name" "$BACKUP_DIR/"
  done

  python3 - "$BACKUP_DIR" <<'PY'
import sqlite3
import sys
from pathlib import Path

root = Path(sys.argv[1])
for name in ("state.db", "kanban.db"):
    file = root / name
    if not file.is_file() or file.stat().st_size == 0:
        raise SystemExit(f"[FAIL] {name}: host copy missing or empty")
    with sqlite3.connect(file.as_uri() + "?mode=ro&immutable=1", uri=True) as db:
        result = db.execute("PRAGMA quick_check").fetchall()
    if result != [("ok",)]:
        raise SystemExit(f"[FAIL] {name}: host copy quick_check failed")
    print(f"[OK] {name}: downloaded; host quick_check=ok")
PY
  printf 'BACKUP_DIR=%s\n' "$BACKUP_DIR"
)
```

The `BACKUP_DIR` line is for the owner's local records only. Do
**not** share the location, files, DB contents or user-sensitive logs.
The two `[OK]` checks alone are sufficient acceptance evidence.
Leave the original snapshots intact for now. The WSL host copy can
still disappear if that distro is removed/damaged. Next: protected
off-distro storage, then a separate restoration proof. No raw
`/sandbox/.hermes/state.db` or `kanban.db` download is intended.

## Owner private host download accepted (2026-11-19)

The owner reports the two finished SQLite snapshot files were
successfully transferred from sandbox staging to a private
`AIW-Nemo` **host** directory using the official `nemohermes
download` path. The host-side verification command completed
after correcting an initially confused `SNAPSHOT_DIR` (sandbox
source) versus `BACKUP_DIR` (Linux host destination) substitution.

Neither temporary path is a provider route or persistent state
registry. Both directories are **inside the same WSL distribution**,
so neither protects against losing `AIW-Nemo`. The host download
success is not a complete restore guarantee.

## Next owner check: prerequisites for encrypted off-distro storage

Run from `AIW-Nemo` host shell, not inside Hermes:

```bash
printf 'Encryption tool: '
if command -v gpg >/dev/null 2>&1; then
  gpg --version | head -n 1
else
  echo 'GPG unavailable'
fi
printf 'Archive tool: '
if command -v tar >/dev/null 2>&1; then
  tar --version | head -n 1
else
  echo 'tar unavailable'
fi
if [ -d /mnt/c ]; then
  echo '[OK] Windows C: mount is visible from WSL'
else
  echo '[INFO] No /mnt/c mount: choose an accessible external destination'
fi
```

This probe is **read-only**. Do not install packages or copy
sensitive data just to obtain a green result. If GPG or a usable
destination is missing, choose a supported encryption option first.

For the eventual encrypted archive, include the **verified
host-side** SQLite snapshots and the earlier host `SOUL.md` copy,
and separately review the `profiles/`, `platforms/`, `kanban/`
state plus registry and external provider credential bindings.
Encrypt **before** placing copies on a Windows drive or a shared
folder; avoid a OneDrive-synchronized directory unless deliberate
encrypted-cloud backup is intended. Pick a private Windows/external
path under an appropriate secure retention policy and store the
decryption passphrase independently in a password manager.
A second directory under the same WSL distro is **not** off-distro.
An encrypted file on the same Windows physical disk protects
against WSL distro deletion, **not** full disk failure. A separate
encrypted medium or backed-up location is needed for broader
disaster recovery.

No encrypted external copy, decryption test, or restore was reported
as passed in this checkpoint. Do not delete the private original
host/sandbox snapshot files yet.

## Encryption preflight accepted (2026-11-20)

The owner confirmed GnuPG 2.4.8, GNU tar 1.35 and the Windows `/mnt/c` mount
from the `AIW-Nemo` Linux host. No encrypted copy has yet been made.

## Next test: AES-256 encrypted partial backup outside the WSL distro

From the `AIW-Nemo` **host shell** only. The command finds exactly one
`sqlite-*` host directory and one `soul-copy-*/SOUL.md`. It **stops**
if sources are ambiguous; it never guesses a newest backup. All cleartext
stays on Linux. Only encrypted bytes are written into Windows storage.
Choose a non-synchronized writable Windows folder. The example path
`/mnt/c/AIW-Private-Backups` may need changing to a local user folder.
Do **not** use sudo to defeat Windows folder permissions. GPG requests
a password interactively: use a strong unique passphrase and save it
in a password manager, not on the shell command line or in this chat.

```bash
(
  set -euo pipefail
  umask 077
  ROOT="$HOME/hermes-private-backups"
  WIN_DIR="/mnt/c/AIW-Private-Backups"
  mapfile -d '' -t dbdirs < <(
    find "$ROOT" -mindepth 1 -maxdepth 1 -type d -name 'sqlite-*' -print0
  )
  mapfile -d '' -t souls < <(
    find "$ROOT" -mindepth 2 -maxdepth 2 -type f -path "$ROOT/soul-copy-*/SOUL.md" -print0
  )
  if (( ${#dbdirs[@]} != 1 || ${#souls[@]} != 1 )); then
    echo '[STOP] Multiple/missing SQLite or SOUL sources; check locally.'
    exit 1
  fi
  DB_DIR="${dbdirs[0]}"
  SOUL_DIR="$(dirname -- "${souls[0]}")"
  for name in state.db kanban.db; do
    [[ -f "$DB_DIR/$name" && -s "$DB_DIR/$name" && ! -L "$DB_DIR/$name" ]] || exit 1
  done
  [[ -s "$SOUL_DIR/SOUL.md" && ! -L "$SOUL_DIR/SOUL.md" ]] || exit 1
  mkdir -p -- "$WIN_DIR"
  ARCHIVE="$WIN_DIR/hermes-partial-$(date +%Y%m%d-%H%M%S).tar.gz.gpg"
  PART="$ARCHIVE.partial"
  [[ ! -e "$ARCHIVE" && ! -e "$PART" ]] || exit 1
  trap 'rm -f -- "$PART"' EXIT
  export GPG_TTY="$(tty)"
  tar -czf - -C "$DB_DIR" state.db kanban.db -C "$SOUL_DIR" SOUL.md |
    gpg --symmetric --cipher-algo AES256 --output "$PART"
  contents="$(gpg --decrypt "$PART" | tar -tzf -)"
  expected="$(printf 'state.db\nkanban.db\nSOUL.md')"
  [[ "$contents" == "$expected" ]] || {
    echo '[FAIL] Encrypted archive contents mismatch.'
    exit 1
  }
  mv -- "$PART" "$ARCHIVE"
  echo '[OK] Encrypted off-distro archive created and read back.'
)
```

The verification decrypts through a **pipe**, not into a Windows file.
GPG may cache the passphrase, so this first check does not prove that
you can remember it later. Retain the existing originals until a
separate restore test succeeds. This archive covers only `SOUL.md`,
`state.db`, and `kanban.db`: **profiles, platforms, kanban attachments,
host NemoClaw registry and OpenShell credentials are not included**.
An archive on the same physical Windows disk protects against WSL distro
loss, not against disk failure. A genuinely independent backup requires
a separately protected destination.

References: [GnuPG encryption](https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html)
and [GNU tar -C](https://www.gnu.org/software/tar/manual/html_node/Position_002dSensitive-Options.html).
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

For the main SQLite files `state.db` and `kanban.db`, prefer
an explicit SQLite **online snapshot** as above (and download only
those verified snapshots), not a direct copy of a live database file.
For any future stop-based transfer, first agree on a safe interruption
window, exit live Hermes sessions, stop **only** `testhermes01` and
confirm `Stopped` before copying a source database file. If the
upstream download requires a running sandbox, **stop the procedure**
rather than automatically starting or rebuilding it. Never equate
`Stopped` with a complete independent backup.

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
# For databases, download ONLY the completed private online snapshot,
# using its exact SNAPSHOT_DIR from above (not /sandbox/.hermes/state.db).
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
