# 2026-09-30 - Project Configuration and Ownership

> **Work in progress.** This document is being built up one area at a time, possibly across several sessions. Nothing here is decided until the final pass.

Follows the research phase of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).

## Status

**Phase 1: Inventory.** Proposed groups written up, awaiting review. Next: agree the groups, then fill in the inventory one group at a time.

## Purpose

Each research investigation has a plausible direction, but they overlap on project configuration and ownership:

- [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md) proposes capability inputs to shared workflows.
- [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) proposes a project configuration that selects capabilities and their settings.
- [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md) proposes capability answers, potentially doubling as that project configuration.
- [Paket](./2026-09-30%20-%20Paket.md) leaves open how capabilities add or remove dependencies while preserving Dependabot's version changes.

Those proposals need a shared ownership model before their individual contracts can be written confidently. This document establishes that model.

## Scope

One worked example: a repository combining Rust and container capabilities, as envisaged for `bsdev`. We walk through declaring those capabilities, adding one later, and removing one. For each change we establish:

1. Where the authoritative declaration lives.
2. Which parts consume it directly and which need generated files.
3. Who may change those files, including the repository maintainer and Dependabot.
4. What should happen to local customisations when a capability changes.

Out of scope for now: file formats, exact field names, package names and implementation sequencing. The research's preferred tools stay provisional where their behaviour still needs verification.

## Deliverable

A short ownership table and any unresolved questions exposed by the example.

## Stopping point

We can explain how one capability change reaches each affected part of a repository without competing sources of truth or ambiguous ownership.

## Terms

These describe what a word refers to, not decisions. New terms are added as they come up.

| Term | Meaning |
| --- | --- |
| **Project type** | Today's model: one label per repository (`bsdev`, `PowerShellModule`) that selects every generated file. Being replaced by capabilities. |
| **Capability** | A named piece of shared process that a repository opts into, e.g. `rust`, `container`, `powershell-module`. A repository can combine several. |
| **Information** | A single fact about a repository that something reads, e.g. its capabilities, the binary name, the Docker context. |
| **Source of truth** | The one place a piece of information is authoritatively stated. Two places both treated as authoritative for the same information are *competing* sources of truth. |
| **Reader** | Anything that uses a piece of information, inside the repository (build tasks, workflows, Dependabot) or outside it (Terraform). |
| **Generated file** | A committed file whose content a tool produces from information held elsewhere, and which has to be regenerated when that information changes. |
| **Writer** | Any person or automation that changes a file, e.g. the maintainer, Dependabot, the sync mechanism. |
| **Owner** | A writer that is *allowed* to change a given file, or a given part of one. Ownership is the rule; writing is the act. |
| **Maintainer** | The people responsible for a repository. |
| **Sync mechanism** | Whatever brings shared files in a repository up to date with their central source. Provisionally Copier, per [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md). |
| **Local customisation** | A change the maintainer makes in one repository to a file that comes from somewhere shared, e.g. extra cSpell words, a manually defined `.gitignore` entry. Dependabot's edits are tracked separately. |
| **Change trace** | Phase 2's record of one change (declare, add, remove): which information and files it touches. |

## Method

Three phases. Each finishes with a stable output before the next starts, so work can be handed off between sessions.

1. **Inventory (facts only).** Every piece of information the `rust` and `container` capabilities involve in `bsdev` today: where it's stated (every place), what reads it, what writes it, when it changes. No proposals, no owners. Complete when every group has been checked against the sources below and reviewed.
2. **Change traces (facts plus research proposals).** For each change (declare `rust` + `container`, add a capability, remove `container`): which inventory rows change, which files must change, and where each research doc's proposal would leave more than one source of truth or an unclear writer. No decisions. Complete when every conflict is listed.
3. **Decisions.** One conflict at a time, each set out as: question, today, readers, options (with consequences for `bsdev` on declare, add and remove), knock-on for the research docs, recommendation and confidence. Whether a declaration exists, what it holds and where it lives are decided last.

Rules:

- Every fact carries a file reference so anyone can check it.
- Decisions rely only on earlier ones. If a later finding shows an earlier decision was wrong, it's reopened explicitly.
- The Status section is updated at the end of each session.
- No git history of Brownserve repositories is consulted (per the brief).

Sources checked:

- `bsdev`: `~/host-repos/Brownserve/bsdev`
- The generator: `Module/Private/Build/Compare-BrownserveRepository.ps1`, `Module/Private/.config/`, `Module/Private/Build/templates/`
- Terraform: `~/host-repos/Brownserve/Terraform/GitHub`

## Phase 1: Inventory

In progress

## Phase 2: Change traces

Not started.

## Phase 3: Decisions

Not started.

## Open questions

None yet.
