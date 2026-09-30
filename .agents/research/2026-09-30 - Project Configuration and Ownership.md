# 2026-09-30 - Project Configuration and Ownership

> **Work in progress.** This document is being built up one area at a time, possibly across several sessions. Nothing here is decided until the final pass.

Follows the research phase of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).

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
| **Declaration** | The authoritative statement of what a repository uses: at minimum, its capabilities. When anything disagrees with it, the declaration wins. |
| **Source of truth** | The one place a piece of information is authoritatively stated. Two places both treated as authoritative for the same information are *competing* sources of truth. |
| **Consumer** | Anything whose content or behaviour depends on the declaration, inside the repository (build tasks, workflows, `dependabot.yml`) or outside it (Terraform). |
| **Direct consumer** | A consumer that reads the declaration itself whenever it runs. |
| **Generated file** | A committed file whose content is derived from the declaration ahead of time, and has to be regenerated when the declaration changes. |
| **Writer** | Any person or automation that changes a file, e.g. the maintainer, Dependabot, the sync mechanism. |
| **Owner** | A writer that is *allowed* to change a given file, or a given part of one. Ownership is the rule; writing is the act. |
| **Maintainer** | The people responsible for a repository. |
| **Sync mechanism** | Whatever brings shared files in a repository up to date with their central source. Provisionally Copier, per [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md). |
| **Local customisation** | A change the maintainer makes in one repository to a file that comes from somewhere shared, e.g. extra cSpell words, `bsdev`'s `publish_to` input. Dependabot's edits are tracked separately. |
| **Pass / stop** | This document's method. A pass follows one change (declare, add, remove). A stop is one part of the repository visited during a pass. |

## Method

- The example raises each decision. Nothing is decided until the example forces the question.
- One decision at a time, with the facts gathered at that point, options, trade-offs and a recommendation.
- Each decision relies only on earlier ones. If a later stop shows an earlier decision was wrong, it's reopened explicitly.
- Decisions are recorded as they're made, so this document always shows where we stopped.

We follow one change through the repository, one stop at a time, in three passes:

1. **Declare** `rust` + `container`. Visits every stop and settles who owns what when nothing is changing.
2. **Add** a capability. Revisits stops 1 to 7, asking only what the change adds.
3. **Remove** `container`. As pass 2.

Stops (provisional order):

1. The declaration: what it states and who writes it
2. Build tasks
3. CI workflows (stub and Tier 2)
4. `dependabot.yml`
5. Dependency manifests
6. Other repository files the capabilities affect
7. Outside the repository (Terraform)
8. Where the declaration lives (pass 1 only, decided once all the constraints from stops 2 to 7 are in)

## Walkthrough

### Pass 1: Declare

#### Stop 1: The declaration

In progress.

What `bsdev` has today:

- `.brownserve_repository_manifest` states only `RepositoryType: bsdev` and a hardcoded `ManifestVersion: 1.0.0`. The generator writes it.
- Project settings are implicit. Binary and image names default to the repo name in `build_tasks.ps1`, and `build.ps1` also hardcodes `BinaryName = 'bsdev'`. The Docker context (`image/`) is baked into the type's tasks.
- Publish targets (`DockerHub`, `GHCR`, `GitHub`) and the Rust target triple are `build.ps1` parameters, chosen per run.

What the research proposes the declaration might hold:

- Capabilities (all four docs).
- Per-capability settings such as binary name, image name, docs path and publish targets (Invoke-Build P2).
- The template version, ejected paths and a rollout channel (Updating Distributed Files, as Copier answers).

### Pass 2: Add

Not started.

### Pass 3: Remove

Not started.

## Constraints on the declaration's location

Collected at each stop for stop 8. None yet.

## Decisions log

None yet.

## Open questions

None yet.
