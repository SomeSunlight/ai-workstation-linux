# AI Workstation Linux — Local Context Source
<!-- ctx:node id="b1602355-12c7-4664-9b79-09cf20764c82" name="AI Workstation Linux" version="0.1.1-draft" -->

<!-- contextcanon:format Node
Format: Node metadata follows the # title: ctx:node id="..." name="..." version="...". Preserve existing identity.
Details: CONTEXT-format.md
-->

<!-- contextcanon:source-help:intro:start -->
Edit this local Context source; ContextCanon generates CONTEXT.md from it.
Some sections use a strict syntax. The comments below show the expected format.
New Rules, Topics and Resources receive IDs automatically during build; preserve existing IDs.
See [the source format guide](CONTEXT-format.md) for examples and editing instructions.
<!-- contextcanon:source-help:intro:end -->

## Context Imports

<!-- contextcanon:format Context Imports
Format: - [Name](location) — `version` — `relationship=parent|reference`; optional indented Why:, then ctx:source metadata. Preserve exact pins; use source list/adopt/update for package identity.
Details: CONTEXT-format.md
-->

<!-- Import the current Development Workflow package using ContextCanon
     source adopt/update on a qualified workstation. Do not hand-edit
     machine-significant package pins or generated .context entries. -->

- [Development Workflow](contextcanon.yaml) — `0.3.9-draft` — `relationship=parent`
  <!-- ctx:source id="c4c94726-3cc7-4df6-b779-72bbf9c06f40" version="0.3.9-draft" normalized-digest="f65995239d42a95e91f1f3353772c1c867e8cdac71ba7a8a271cd2ae3e84ddf6" package-digest="a9cfabdda18aaf0ad33f06708757bd9e73b58243778913e674737e491c31a36c" -->

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

Standalone portable Ubuntu Linux installer and operator for rootless
Podman, NVIDIA NemoClaw/OpenShell and Hermes. It does not depend
on the Windows AI Workstation, Windows Dispatcher, or WSL APIs.

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

### Linux project boundaries

- **Keep Windows and Linux release identities separate:** Linux ships its own CI, version and Git provenance; a Windows bootstrap selects a verified immutable Linux commit. Never infer Linux code from the current Windows branch.
  Why: Cross-OS branch drift caused the wrong Hermes operator menu to run.
  <!-- ctx:rule id="RULE-A496415DCB9D" -->

- **Preserve vendor-owned agent state:** Defer sandbox lifecycle and policy authority to upstream NemoClaw/OpenShell, and never run rebuild, destroy, provider changes or onboarding during a normal status, verify or launch.
  Why: A routine restart must not destroy user artifacts or credentials.
  <!-- ctx:rule id="RULE-2234D2634DC1" -->

- **Keep native Ubuntu portable:** Neither install nor verify may require PowerShell, Windows executables, WSL-specific paths or native Windows service processes.
  Why: The same artifact must work on a native Ubuntu host.
  <!-- ctx:rule id="RULE-06C5FA29495A" -->

- **Keep secrets out of source and logs:** Use the official NemoClaw credential bridge and explicit allowlists for any approved private inference endpoint.
  Why: Agents remain bounded by upstream security controls.
  <!-- ctx:rule id="RULE-B532DB589234" -->
