# AI Workstation Linux — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** AI Workstation Linux  
**Context version:** `0.1.0-draft`

## Local Overview

Standalone portable Ubuntu Linux installer and operator for rootless
Podman, NVIDIA NemoClaw/OpenShell and Hermes. It does not depend
on the Windows AI Workstation, Windows Dispatcher, or WSL APIs.

## How to use this context

Apply all Rules below to every task in this Node.

## Local Rules

### Linux project boundaries

#### `RULE-A496415DCB9D` — Keep Windows and Linux release identities separate

Linux ships its own CI, version and Git provenance; a Windows bootstrap selects a verified immutable Linux commit. Never infer Linux code from the current Windows branch.

#### `RULE-2234D2634DC1` — Preserve vendor-owned agent state

Defer sandbox lifecycle and policy authority to upstream NemoClaw/OpenShell, and never run rebuild, destroy, provider changes or onboarding during a normal status, verify or launch.

#### `RULE-06C5FA29495A` — Keep native Ubuntu portable

Neither install nor verify may require PowerShell, Windows executables, WSL-specific paths or native Windows service processes.

#### `RULE-B532DB589234` — Keep secrets out of source and logs

Use the official NemoClaw credential bridge and explicit allowlists for any approved private inference endpoint.
