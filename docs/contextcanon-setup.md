# ContextCanon integration — Linux development branch

**Status:** reusable Development Workflow parent not yet adopted or built.
This document supplies the exact non-destructive procedure; do not write
`ctx:source` metadata, digests or generated `.context` packages manually.

The local [CONTEXT.src.md](../CONTEXT.src.md) contains the independent Linux
rules and a stable Node identity. [contextcanon.yaml](../contextcanon.yaml)
declares the reviewed Development Workflow upstream mapping to
`SomeSunlight/context-canon`. Parent version `0.3.9-draft` was observed
upstream on 2026-11-18; the **exact accepted commit and package digests
must come from ContextCanon's official source adoption**, not from the
branch name or this documentation.

## On a separate development checkout

Use a **development checkout**, preferably outside the live WSL test distro.
ContextCanon is a developer utility, not an upstream Hermes requirement,
and is not installed by `./install.sh`. A Windows development checkout
is fine even though the resulting repository builds and runs on Ubuntu.

Ensure `contextcanon --version` reports an installed CLI supporting
`source adopt` and `build`. If needed, install or update the tool
using the official ContextCanon README. Verify that the independent
`context-canon` repository is a clean Git checkout at the reviewed
revision and has a published `nodes/library/development-workflow/CONTEXT.md`.

With the **new Linux repository development checkout** as current
directory, first let ContextCanon publish the local Node without a
Parent, then adopt the exact reviewed upstream package:

```bash
contextcanon --version
contextcanon build .
contextcanon check .
# Supply the real local path to your CLEAN context-canon checkout:
contextcanon source adopt /path/to/context-canon/nodes/library/development-workflow --node .
contextcanon source list
contextcanon build .
contextcanon check --all .
git status --short
```

The first `build` may normalize `CONTEXT.src.md`, create
`CONTEXT-format.md`, `CONTEXT.md`, `CONTEXT/` and immutable
`.context/` packages, and assign IDs to local rules. This is
**expected generated output** and should be reviewed, not fabricated.
`source adopt` is the first adoption of a published package and records
the exact Git commit/node path/package digests after validating the
prospective composition. It must succeed **before** we claim CCW-014
and CCW-017 are inherited. Later parent updates use
`contextcanon source update "Development Workflow"`, not another
first adoption or an unreviewed `git pull`.

If the command reports a malformed Node or a conflicting rule, stop
and share the exact diagnostics. Do not hand-edit generated files or
discard accepted context identities just to silence the error.
Commit/push only the intended authored and generated output on the
**Linux draft PR branch** after review; never on `main`.
The CI can then gain the same read-only `contextcanon check --all .`
gate as the other projects using an exact CLI pin.

This is **source-only**: the process must not run
`./install.sh install`, `nemohermes onboard`, Podman reconfiguration,
or any Hermes sandbox lifecycle command.

References: [official maintenance workflow](https://github.com/SomeSunlight/context-canon/blob/main/docs/maintenance.md),
[ContextCanon CLI](https://github.com/SomeSunlight/context-canon/blob/main/docs/cli.md),
[exact first adoption](https://github.com/SomeSunlight/context-canon/blob/main/nodes/internal/framework-development/docs/external-sources.md).
