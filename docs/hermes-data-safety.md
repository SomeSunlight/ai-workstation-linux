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

## Installed CLI confirmation (2026-11-20)

The owner ran `hermes backup --help` inside `testhermes01`.
The installed Hermes CLI **does** expose full backup with optional
`-o/--output`, `-q/--quick`, `-l/--label` (quick-only) and
`-k/--keep N` (default 3, **0 keeps everything**).
The help command is read-only; **no official full ZIP has been
created yet**. The owner did not report a version string, so none
is asserted here.

## Next owner test: native full Hermes backup (NOT YET EXECUTED)

Inside the existing `testhermes01` sandbox shell:

```bash
umask 077
hermes backup --keep 0
```

This requests a **full** Hermes backup using its standard timestamped
`~/hermes-backup-<timestamp>.zip` output path, while **preserving older
backups**. Do not add `--quick`, which omits much of the user state.
Record the resulting archive path locally and confirm the tool exits
successfully (no incomplete-backup warning). Share a sanitized
success/error summary only; never share the archive or secret-bearing
file names/logs. The ZIP is **not encrypted** and can contain tokens,
credentials and private user data. Keep it inside the sandbox until
the separate private-host download and encrypted export steps are
agreed. Do not import it into the existing sandbox.

## Owner full Hermes backup accepted (2026-11-20)

The owner reports a successful **official full** Hermes backup of
**2,824 files**. Hermes printed the restore hint
`hermes import hermes-backup-2026-11-19-232806.zip`.
No import was performed, and the running `testhermes01` was not
replaced. The archive name is evidence of an output file, but ZIP
integrity and off-distro custody have **not** yet been independently
checked.

## Next owner test: download and read-test the official ZIP

From an `AIW-Nemo` **host shell**, outside the sandbox:

```bash
(
  set -euo pipefail
  umask 077
  export PATH="$HOME/.local/bin:$PATH"
  export NEMOCLAW_GATEWAY_RUNTIME=podman
  ROOT="$HOME/hermes-private-backups"
  install -d -m 700 "$ROOT"
  DEST="$(mktemp -d "$ROOT/hermes-full-XXXXXXXX")"
  NAME="hermes-backup-2026-11-19-232806.zip"

  nemohermes testhermes01 download "/sandbox/$NAME" "$DEST/"

  python3 - "$DEST/$NAME" <<'PY'
from pathlib import Path
import sys
import zipfile

path = Path(sys.argv[1])
if not path.is_file() or path.stat().st_size == 0:
    raise SystemExit("[FAIL] Official Hermes ZIP missing or empty")
with zipfile.ZipFile(path) as archive:
    if not archive.infolist():
        raise SystemExit("[FAIL] Official Hermes ZIP is empty")
    if archive.testzip() is not None:
        raise SystemExit("[FAIL] Official Hermes ZIP CRC verification failed")
print("[OK] Official Hermes ZIP copied; CRC verified.")
PY
)
```

The path `/sandbox/<name>` follows the default Hermes backup path
(`~` inside this sandbox is `/sandbox`). If the download reports
source missing, **stop and inspect the original archive location inside
the sandbox**; do not guess or recursively search host secrets.
The host ZIP is a **sensitive plaintext archive**, potentially with
credentials. It must remain inside private `AIW-Nemo` storage until
encrypted for an off-distro destination. Do not list its entries
in chat or GitHub, use `hermes import` on the live sandbox, or
delete the existing private copies. CRC proves archive transport
integrity, not full application-level restore capability.

## Official Hermes ZIP: independent host copy verified (2026-11-20)

The owner confirms that the **full 2,824-file** official Hermes backup
ZIP was downloaded to a private `AIW-Nemo` host directory and the
independent ZIP CRC/readability test returned
`[OK] Official Hermes ZIP copied; CRC verified.`

This verifies the host copy, **not** a full application import or
protection against loss of the WSL distribution.

## Next owner test: encrypt the official ZIP outside WSL

The only remaining data-export operation uses **GnuPG directly**,
not a custom AIW backup archiver. It encrypts the **one existing
Hermes ZIP** from inside WSL and writes only encrypted bytes to an
ordinary Windows directory. Do not place unencrypted ZIP files in
Windows or a sync folder.

From the `AIW-Nemo` **host shell** (not the sandbox):

```bash
(
  set -euo pipefail
  umask 077
  ROOT="$HOME/hermes-private-backups"
  NAME="hermes-backup-2026-11-19-232806.zip"
  WIN_DIR="/mnt/c/AIW-Encrypted-Backups"

  mapfile -d '' -t files < <(
    find "$ROOT" -mindepth 2 -maxdepth 2 -type f \
      -path "$ROOT/hermes-full-*/$NAME" -print0
  )
  if (( ${#files[@]} != 1 )); then
    echo '[STOP] Official Hermes ZIP not uniquely found.'
    exit 1
  fi
  SRC="${files[0]}"
  [[ -s "$SRC" && ! -L "$SRC" ]] || exit 1

  mkdir -p -- "$WIN_DIR"
  DEST="$WIN_DIR/$NAME.gpg"
  PART="$DEST.partial"
  [[ ! -e "$DEST" && ! -e "$PART" ]] || {
    echo '[STOP] Destination exists; nothing overwritten.'
    exit 1
  }
  trap 'rm -f -- "$PART"' EXIT

  export GPG_TTY="$(tty)"
  gpg --symmetric --cipher-algo AES256 --output "$PART" "$SRC"
  gpg --decrypt --output - "$PART" | cmp -s - "$SRC"

  mv -- "$PART" "$DEST"
  echo '[OK] Encrypted Hermes backup stored outside WSL; bytes verified.'
)
```

GPG will request a **strong passphrase interactively**; keep it in
a password manager. Do not pass it as a command argument or share it
in chat. The comparison decrypts only into a pipe and checks the
complete bytes against the Linux original, without writing plaintext
to Windows. GPG's local cache may allow the immediate check to
complete without prompting again; storing the password remains
essential. If Windows refuses `/mnt/c/AIW-Encrypted-Backups`, stop
and choose a permitted, non-synchronized Windows directory; do not
use `sudo` to bypass Windows permissions.

The encrypted copy protects against **WSL distribution loss**, not
a failed physical disk if Windows and WSL are on that same disk.
Keep a second protected copy on separate media/storage for that
risk. This is a Hermes **application-level** backup; NemoClaw's
sandbox registry, OpenShell provider bindings, and OS installation
are independently reproducible through supported installation and
onboarding. A full sandbox image or mandatory restore drill is not
required for the Linux PR.

## After a successful full official backup (NOT YET EXECUTED)

1. The official **full** Hermes ZIP has been created and its private
   host copy passed an independent ZIP CRC check.
2. Encrypt the already downloaded official ZIP using GnuPG directly,
   then compare decrypted bytes to the private Linux original (above).
3. Retain the encryption secret separately in a password manager;
   preserve the original ZIP until the encrypted off-WSL copy is proven.
4. If Hermes must be reinstalled, create a new NemoClaw sandbox
   through its supported onboarding, configure its provider and policies,
   then restore only the user data that is appropriate for the new
   environment. Do not blindly overwrite NemoClaw-managed configuration
   or credentials from an older Hermes archive.
5. A full sandbox restore drill is **optional**, not a Linux PR
   acceptance gate. Qualify normal sandbox stop/start and Windows/WSL
   recovery separately, without requiring the whole installation to
   be reconstructed automatically.

**Do not invoke `hermes import` or `nemohermes rebuild` as a
backup verification on the working sandbox.** No new backup
scheduler/service/registry is justified in AIW.

## Explicit recovery priority

The owner accepts reinstalling Hermes from scratch when needed. The
objective is therefore **recoverability of user-owned data and work**,
not recreating an identical Podman/NemoClaw/OpenShell runtime from a
backup. Maintain a simple documented reinstallation/onboarding route;
avoid a parallel AIW snapshot engine, another registry or a mandatory
end-to-end sandbox restore certification.

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
