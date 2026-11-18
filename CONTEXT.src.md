# AI Workstation Linux — Local Context Source
<!-- ctx:node id="b1602355-12c7-4664-9b79-09cf20764c82" name="AI Workstation Linux" version="0.1.0-draft" -->

## Context Imports

<!-- Import the current Development Workflow package using ContextCanon
     source adopt/update on a qualified workstation. Do not hand-edit
     machine-significant package pins or generated .context entries. -->

## Local Overview

Standalone portable Ubuntu Linux installer and operator for rootless
Podman, NVIDIA NemoClaw/OpenShell and Hermes. It does not depend
on the Windows AI Workstation, Windows Dispatcher, or WSL APIs.

## Local Rules

### Linux project boundaries

- **Keep Windows and Linux release identities separate:** Linux ships its own CI, version and Git provenance; a Windows bootstrap selects a verified immutable Linux commit. Never infer Linux code from the current Windows branch.
  Why: Cross-OS branch drift caused the wrong Hermes operator menu to run.

- **Preserve vendor-owned agent state:** Defer sandbox lifecycle and policy authority to upstream NemoClaw/OpenShell, and never run rebuild, destroy, provider changes or onboarding during a normal status, verify or launch.
  Why: A routine restart must not destroy user artifacts or credentials.

- **Keep native Ubuntu portable:** Neither install nor verify may require PowerShell, Windows executables, WSL-specific paths or native Windows service processes.
  Why: The same artifact must work on a native Ubuntu host.

- **Keep secrets out of source and logs:** Use the official NemoClaw credential bridge and explicit allowlists for any approved private inference endpoint.
  Why: Agents remain bounded by upstream security controls.
