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

## Decisions log

None yet.

## Open questions

None yet.
