# Controlled Hermes recovery and restart qualification

**Status: procedure prepared, NOT executed on the owner's host (2026-11-20).**
The owner prioritizes learning Hermes and making its tooling useful for
real tasks with local Strata/Dispatcher inference. WSL/Windows reboot
robustness is a desirable later qualification, not a gate that justifies
weeks of speculative Podman or OpenShell debugging.

This is a short *operator playbook*, not a new AIW lifecycle engine.
AIW reads the vendor configuration, delegates all lifecycle operations
to upstream NemoClaw/OpenShell, and never edits Podman container metadata.

## Known incident and verified cause

Existing `testhermes01` in `AIW-Nemo` (Ubuntu 26.04,
rootless Podman 5.7, OpenShell **0.0.116**) was working before an
unexpected Windows/WSL reboot. A subsequent `nemohermes testhermes01
start` failed after the sandbox container exited **1**, OOM=false.
Sandbox logs identified the **real failing operation**:

```text
Policy fetch failed after 5 attempts: failed to connect to OpenShell server
```

Owner tests isolated a stale Podman sandbox host alias:
- Stored `HostConfig.ExtraHosts`: `host.containers.internal` and
  `host.openshell.internal` both **169.254.2.2**.
- A fresh unprivileged disposable container on the *same* network
  `openshell-docker` resolved the current host alias as **169.254.1.2**.
- TCP from that fresh container to the WSL OpenShell listener:
  **169.254.1.2:8080 succeeded; 169.254.2.2:8080 timed out**.
- OpenShell gateway itself was healthy on the host and bound
  `0.0.0.0:8080`; rootless Podman socket was active. The bridge was
  `10.89.0.0/24`, gateway `10.89.0.1`; these are separate from the
  host-gateway alias.
- External local inference host had the expected fixed private DNS
  address; HTTPS `GET /v1/models` returned **401** (reachable/auth
  required, not authenticated inference).
- After the disposable test, its `pasta` process was gone. This is
  not evidence of a persistent zombie or service failure.

**This is a host-callback issue before normal Hermes start; the
inference-health failure is secondary.** The address values above are
observed *in this particular private setup*, not constants to apply to
other installations. Windows and WSL can regenerate network mapping;
do not pin or open the link-local host-gateway IP through a broad
firewall/SSRF bypass.

## Safety gate: completed native Hermes backup

Owner produced a **full native `hermes backup --keep 0`** ZIP of
**2,824 files**, copied it from the existing sandbox to private
WSL-host storage, verified ZIP CRC, and created a GPG AES-256 encrypted
copy on **another Windows drive** with byte-for-byte decrypted
comparison. The encryption passphrase is separate. This establishes
application-data preservation, *not* an OpenShell/NemoClaw credential
or entire WSL image backup, and not a completed import test.

Never print private URLs, raw policy logs, credentials or backup
contents into CI, GitHub issues or public PR descriptions.

## Priority 1: one bounded vendor-supported recovery attempt

1. Read the current named-sandbox status and host mappings through
   `aiw` option 7, or `aiw network --sandbox testhermes01`.
   Capture one restricted baseline snapshot (examples below).
2. Check the **installed** NemoClaw/OpenShell help and the exact pinned
   upstream semantics for a *supported*, reversible in-place
   rebinding of the old container's host callback that **guarantees
   preservation of the native Hermes home** and does not implicitly
   recreate or overwrite the original. Document the chosen action
   and its expected state effects before running it.
3. If no such documented, safe mechanism exists, **STOP this branch**.
   The owner has **already tested** the ordinary `start` path; it failed
   because it reused the stale host alias. A repeated `start`, blind
   `recover`, `connect` with potential recreate side effects,
   `rebuild`, `podman network reload` or manually patching internal
   Podman JSON is not a justified substitute. The vendor's standard
   stopped-Hermes rebuild may itself require starting the broken source
   to capture state.
4. Only if a bounded safe operation is found and operator-approved:
   run it once, record identity of the same sandbox and preservation
   of native home, capture the post-action snapshot, and verify status,
   policy fetch, `Ready`, local provider inference and a tiny Hermes
   interaction. If it fails, do not improvise additional repairs.

**Source-review result (2026-11-20):** OpenShell's exact installed
**v0.0.116** [sandbox CLI command set](https://github.com/NVIDIA/OpenShell/blob/v0.0.116/crates/openshell-cli/src/main.rs#L1334-L1675)
offers `create`, `get`, `list`, `delete`, `stop`, `start`, `exec`,
`connect`, `upload`, `download`, and provider operations; **no
documented in-place host-alias rebind/refresh**. The owner's real
`nemohermes testhermes01 start` attempt has already failed. Podman's
container-update contract does not expose a supported static
`ExtraHosts` rewrite. The bounded **vendor-only in-place recovery gate
therefore has no qualified safe action at this pinned version**:
**stop here, preserve the original, and prepare a new sandbox**.
This does *not* claim that an undocumented repair is impossible or
that later upstream releases cannot fix it; it deliberately avoids
unsupported, persistent-container surgery.

## Priority 2: complete predictable AIW entry points

**Windows PR #84** defines two AIW-owned penguins for `AIW-Nemo`.
The project penguin opens a real Linux login shell in
`/home/<user>/ai-workstation-linux`; the home penguin opens it in
`/home/<user>`. Neither auto-starts a menu. Inside either terminal,
`aiw` explicitly opens the Linux menu, and `q` returns to the **Linux
shell**, not PowerShell.

**Linux PR #1** introduces `./install.sh register-cli` (user-only,
no sudo, collision-safe), which creates `~/.local/bin/aiw`. Use it
before refreshing the Windows shortcuts. A separate Windows
read-only handoff PR #85 remains an **independent, pinned version
cutover**; it must not auto-update Linux source, change other WSL
distros or install services.

The standard status action now includes a read-only network summary.
A selected Hermes sandbox also gets its saved Podman host aliases.
Use `aiw network` explicitly for snapshots/compare or `--probe`
to start a **separate disposable** no-mount Podman test container.
The normal status/compare path never starts any container.

## Private, repeatable IP snapshot

In the **real Linux host shell**, once the reviewed Linux checkout is
updated and `aiw` user command registered:

```bash
umask 077
mkdir -p -m 700 "$HOME/aiw-network-snapshots"
aiw network --sandbox testhermes01 \
  --save "$HOME/aiw-network-snapshots/01-before.json"
```

For an **explicit** temporary bridge test, after checking rootless
Podman runtime readiness and owner consent:

```bash
aiw network --sandbox testhermes01 --probe
```

`--probe` starts one disposable container from the existing local
sandbox image with `--pull=never`, no agent data mounts or copied
credentials. It does **not** start Hermes or change its sandbox.
It is optional and cannot prove that a stopped sandbox itself is
healthy. A missing local image or shell means *unverified*, not
necessarily a broken network.

For a later comparison (choose a **new** destination filename;
snapshot files are never overwritten):

```bash
aiw network --sandbox testhermes01 \
  --save "$HOME/aiw-network-snapshots/02-after.json" \
  --compare "$HOME/aiw-network-snapshots/01-before.json"
```

The snapshot keeps interface addresses, default gateways, configured
Podman bridge networks, stored sandbox alias mappings, and any
provider hostname published in the **official upstream list metadata**
with its DNS resolution. Provider URLs with credentials/query strings
are *not* recorded; values unavailable from the published metadata
are marked unknown. These are **private** user files at mode 0600.
Do not add them to Git or upload them into a chat.

## Priority 3: new sandbox if recovery cannot be qualified

Do **not** destroy `testhermes01` first. Deliberately create an
independent replacement through **official NemoClaw onboarding**
under a **different name** after checking its required credentials
and precise host/provider policy. Reuse no raw tokens from notes or
a public issue. Test a simple local inference interaction, then use
the supported `hermes import` only for appropriately scoped native
application data (this may replace application configuration; read
upstream `import --help` and validate its effect on a disposable
sandbox first). Keep the encrypted off-WSL backup and original
sandbox untouched until new Hermes state and artifacts are verified.

After owner acceptance, consider retiring the old sandbox by its
**exact registered name** using upstream tools and explicit
destructive confirmation. No AIW auto-destroy.

## Priority 4: controlled restart qualification, one gate at a time

Stop when a gate fails; do **not** treat later gates as required for
Hermes productivity. Obtain baseline IP snapshots and status before
each gate, and compare to after. Confirm preserved Hermes files and
the local model request with minimal tests.

1. **Hermes only**: exit interactive chat, stop the specific sandbox,
   verify stopped, start it and reattach. Distinguish chat exit,
   sandbox stop and OpenShell gateway shutdown.
2. **Hermes + NemoClaw**: clean sandbox stop, then official gateway
   shutdown/start using commands confirmed against the *installed*
   CLI, not guessed systemd names. Start and reattach Hermes.
3. **Hermes + NemoClaw + WSL**: stop sandbox and official gateway,
   terminate only the dedicated `AIW-Nemo` distro; start via one of
   the penguins, verify gateway health, start Hermes.
4. **Full Windows reboot**: the previous orderly shutdown plus a
   deliberately scheduled Windows restart; preserve unrelated
   distros and Windows services, then verify all layers in order.

No forced crash/corruption test without a separately approved
need. Distinguish a **stopped** sandbox from **Error**, and a gateway
connectivity failure from external Speedy inference reachability.
Stop testing and prioritize agent capabilities if the procedure
requires too much manual repair.

## Primary product goal after basic recovery

Focus on the **actual Hermes/Strata agent workflow**, not on
rebuilding sandbox orchestration:
- Identify why Hermes cannot open and visually validate its own
  generated HTML5/Canvas results. Prior offline Node/Canvas checks
  were successful but were **not** a browser screenshot/visual test;
  Chromium/Playwright browser download was blocked (HTTP 403).
- Determine required tools/images for browser rendering, Python,
  structured testing and common development workflows within the
  OpenShell security boundaries. Prefer trusted prebuilt sandbox
  images and narrowly approved capabilities, not broad network
  bypasses or unrestricted host mounts.
- Test useful end-to-end technical tasks with the local Strata model
  through the Dispatcher. Local agent execution and inference are
  separate architecture choices; do not accidentally move inference
  to a third-party cloud as a recovery workaround.
- Keep native upstream startup and state ownership. Avoid bespoke
  AIW session/backup/policy registries and overlong admin menus.

See the actual evidence in Windows [Issue #83](https://github.com/SomeSunlight/ai-workstation/issues/83),
Linux [Draft PR #1](https://github.com/SomeSunlight/ai-workstation-linux/pull/1),
Windows [Draft PR #84](https://github.com/SomeSunlight/ai-workstation/pull/84),
and the separately gated [Draft PR #85](https://github.com/SomeSunlight/ai-workstation/pull/85).
