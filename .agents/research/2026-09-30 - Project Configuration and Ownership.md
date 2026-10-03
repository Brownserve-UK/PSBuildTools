# 2026-09-30 - Project Configuration and Ownership

> **Work in progress.** This document is being built up one area at a time, possibly across several sessions. Nothing here is decided until the final pass.

Follows the research phase of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).

## Status

**Phase 3: Decisions, continued without Copier.** 3.1 to 3.8 are done. After 3.3 and 3.4, Copier was ruled out (Q12). The likely replacement is a CLI that Brownserve builds and ships, but that isn't confirmed. The decisions so far are split into ownership rules, which stand, and Copier mechanisms, which don't (see [Sync mechanism requirements](#sync-mechanism-requirements)). The Copier findings are now requirements for whatever replaces it. Steps that depend on the sync mechanism (3.9, 3.13, 3.19, 3.21, 3.22) are parked until it's chosen. The rest continue, more briefly where a step is small. Still open from earlier: E12 for NuGet, running the lint CI actions (E9), Feature pins end to end (E22), and security updates against `exclude-paths` (E21). Also: the dev container base image tag and baseline Features (E29), the Node version checks (E30), and Dependabot `npm` updating `package-lock.json` (E31). Next: 3.10, A6.

- [x] 1. Inventory
- [x] 2.1 Agree the map format
- [x] 2.2 Today's map, built from the Phase 1 inventory
- [x] 2.3 Trace A: declare `rust-app` + `container`, filling in the proposed rows it reaches
- [x] 2.4 Extra inventory for `docs-astro`, plus its rows in today's map
- [x] 2.5 Trace B: add `docs-astro`, filling in its proposed rows
- [x] 2.6 Trace C: remove `container`
- [x] 2.7 Problem list: duplicates removed, dependencies noted, order agreed for Phase 3
- [x] 3.1 Exploration: check the E entries in the Register
- [x] 3.2 to 3.4 Decisions: A4, A8 (provisional), A9
- [x] 3.5 Decision: C4
- [x] 3.6 Decision: A7
- [x] Sync mechanism requirements, from the Copier findings
- [x] 3.7 Decision: B3
- [x] 3.8 Decision: T3 and B4
- [ ] 3.5 to 3.20 Decisions that don't depend on the sync mechanism, skipping parked steps
- [ ] Parked until the sync mechanism is chosen: 3.9, 3.13, 3.19, 3.21, 3.22
- [ ] F. Final pass: final map and unresolved questions, re-run the three traces against it, decide whether an overview diagram is worth adding

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

This is not being treated as what a migration of `bsdev` would look like, we are simply using the shape of `bsdev` as a reference point.

## Deliverable

A short ownership table and any unresolved questions exposed by the example.

## Stopping point

We can explain how one capability change reaches each affected part of a repository without competing sources of truth or ambiguous ownership.

## Terms

These describe what a word refers to, not decisions. New terms are added as they come up.

| Term | Meaning |
| --- | --- |
| **Project type** | Today's model: one label per repository (`bsdev`, `PowerShellModule`) that selects every generated file. Being replaced by capabilities. |
| **Capability** | A named piece of shared process that a repository opts into, e.g. `rust-app`, `container`, `powershell-module`. A repository can combine several. |
| **Project config** | The settings file [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) proposes for each repo (`:142`): its capabilities and their settings (binary name, image name, Docker context, publish targets). The build tasks read it. Replaces today's `ModuleInfo.json` and the hard-coded defaults in `build.ps1` and `build_tasks.ps1`. Format and location not decided (`:199`, `:217`). |
| **Task package** | The NuGet package of shared Invoke-Build tasks proposed in [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) (`:85`). It has one base script per capability, and the repo loads them with `Extends`. Name not decided (D8, `:222`). |
| **Dependency manifest** | The file that lists the NuGet packages a repo's build needs. Today that's `paket.dependencies`, which has no versions. Under [Paket](./2026-09-30%20-%20Paket.md) option C it's a small `.csproj` used only for this, with versions, plus a committed lock file, `packages.lock.json` (`:72-78`, `:97`). Name and location not decided; the research's example is `.build/dependencies.csproj` (`:119`). Doesn't cover the `Cargo.toml` files. |
| **Shared workflow** | A reusable GitHub Actions workflow (`on: workflow_call`) kept in a central Brownserve repo and run by other repos. It holds the jobs themselves: matrices, build steps, the gate job. Tier 2 in [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md) (`:59-60`, `:72-79`). Repo name not decided (D5, `:178`). |
| **Stub** | A short workflow file kept in each repo (Tier 3 in [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md), `:81-110`). It has no jobs of its own: it says when to run (triggers), what the run may do (permissions), which secrets to pass and which capabilities apply, then hands over to a shared workflow pinned at a version. GitHub calls this a caller workflow (`:47`). |
| **Information** | A single fact about a repository that something reads, e.g. its capabilities, the binary name, the Docker context. |
| **Source of truth** | The one place a piece of information is authoritatively stated. Two places both treated as authoritative for the same information are *competing* sources of truth. |
| **Reader** | Anything that uses a piece of information, inside the repository (build tasks, workflows, Dependabot) or outside it (Terraform). |
| **Generated file** | A committed file whose content a tool produces from information held elsewhere, and which has to be regenerated when that information changes. |
| **Writer** | Any person or automation that changes a file, e.g. the maintainer, Dependabot, the sync mechanism. |
| **Owner** | A writer that is *allowed* to change a given file, or a given part of one. Ownership is the rule; writing is the act. |
| **Maintainer** | The people responsible for a repository. |
| **Sync mechanism** | Whatever brings shared files in a repository up to date with their central source. Was Copier, per [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md). Now likely a CLI that Brownserve builds, not yet confirmed (Q12). What it has to do is in [Sync mechanism requirements](#sync-mechanism-requirements). |
| **Local customisation** | A change the maintainer makes in one repository to a file that comes from somewhere shared, e.g. extra cSpell words, a manually defined `.gitignore` entry. Dependabot's edits are tracked separately. |
| **Map** | A table of where each piece of content in a repository comes from and how it gets there. Phase 2 builds one for today and one proposed. |
| **Route** | How content gets from where it comes from to where it's used, e.g. the generator, a Dependabot PR, a hand edit. Each piece of content should have exactly one. |
| **Problem** | A map row marked ⚠: two routes into the same thing, a route with no clear writer, or something that needs to change but has no route. |
| **Change trace** | Phase 2's record of one change (declare, add, remove): which source it changes, the map rows reached by following the routes out of it, and the problems found. |
| **Register** | The single list of problems, open questions and things to check, with their dependencies, Phase 3 step and status. |

## Method

This is being done slowly and carefully to assess each area in turn with the user to ensure direction is aligned and help guide towards the correct shape.
Three phases and a final pass. Each finishes with a stable output before the next starts, so work can be handed off between sessions.
File edits must be agreed with the user before writing.

1. **Inventory (facts only).** Every piece of information the `rust-app` and `container` capabilities involve in `bsdev` today: where it's stated (every place), what reads it, what writes it, when it changes. No proposals, no owners. Complete when every group has been checked against the sources below and reviewed.
2. **Change traces (facts plus research proposals).** Build today's map from the inventory, then trace three changes: declare `rust-app` + `container`, add `docs-astro`, remove `container`. Each trace fills in the proposed map rows it reaches from what the research docs propose. No decisions. Complete when every problem is listed and their order for Phase 3 is agreed.
3. **Decisions.** Opens with an exploration session that checks what the decisions rest on. Then one problem at a time, each fixing a row of the proposed map, set out as: question, today, readers, options (with consequences for `bsdev` on declare, add and remove), knock-on for the research docs, recommendation and confidence. Whether a declaration exists, what it holds and where it lives are decided last.
4. **Final pass.** Settle the final map and unresolved questions. Re-run the three traces against the final map; anything still ambiguous reopens a decision or becomes an unresolved question. Proposed rows no trace reached are filled in or marked as unaffected by capabilities.

Map format:

- A list of sources first, each named once: the distinct values of the **Comes from** column.
- One table per area, using the Phase 1 groups, with three columns: **Thing**, **Comes from**, **Gets there by**.
- A row is a file, or part of a file where the parts arrive by different routes.
- ⚠ marks a problem. Problems are listed in the [Register](#register) with an ID.
- The proposed map starts empty and is filled in by the traces.

Trace format: a trace changes one source and follows the routes out of it. It records the rows reached, anything that should change but has no route, and anything reached by two routes. Trace C also covers what happens to local customisations.

Rules:

- Every fact carries a file reference so anyone can check it.
- Decisions rely only on earlier ones. If a later finding shows an earlier decision was wrong, it's reopened explicitly.
- The Status section is updated at the end of each session.
- No git history of Brownserve repositories is consulted (per the brief).
- This document is not updated until the user agrees to it

Sources checked:

- `bsdev`: `~/host-repos/Brownserve/bsdev`
- The generator: `Module/Private/Build/Compare-BrownserveRepository.ps1`, `Module/Private/.config/`, `Module/Private/Build/templates/`, and the `Module/` functions it calls
- Terraform: `~/host-repos/Brownserve/Terraform/GitHub`, and `~/host-repos/Brownserve/Terraform/.gitlab-ci.yml`

## Phase 1: Inventory

Complete.

Files are grouped by the part of the repository that reads them. Each group has a table with one row per file and these columns:

- **Holds:** the information in the file.
- **Comes from:** where that information comes from today.
- **Written by:** who writes the file today.
- **Read by:** what uses the file.
- **Changes when:** what causes the file to change.

Information stated in more than one place is collected in [Repeated information](#repeated-information).

| Group | Files |
| --- | --- |
| Build | `.build/*`, `paket.dependencies`, `nuget.config`, `.config/dotnet-tools.json` |
| CI workflows | `.github/workflows/*` |
| Dependency tooling | `.github/dependabot.yml`, `Cargo.toml` (root, `cli/`, `core/`), `Cargo.lock`, `image/Dockerfile` |
| Dev environment | `.devcontainer/*`, `.vscode/*`, `.editorconfig` |
| Repository hygiene | `.gitignore`, `.markdownlint.json` |
| Docs | `README.md`, `CHANGELOG.md`, `LICENSE`, `CLAUDE.md`, `.github/CONTRIBUTING.md`, `.github/pull_request_template.md` |
| Install scripts | `scripts/install.*` |
| Generator | `.brownserve_repository_manifest` |
| GitHub settings | Terraform `repos.tf`, `secrets.tf`, `apps.tf`; secrets set by hand |

Out of scope:

- Rust and image source (`cli/`, `core/`, the rest of `image/`), unless something above reads information from it.
- `image/proto/`: specific to `bsdev` and likely to be removed.

Confirmed by the maintainer:

- `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` were added to `bsdev` by hand. They aren't in Terraform yet.
- The `publish_to` input in `bsdev`'s `release.yaml` was added by the maintainer. The generated version was wrong, so it was patched in place and never carried back to the template.

Generator references below are to `Compare-BrownserveRepository.ps1` unless stated.

The generator only runs when someone runs `Initialize-BrownserveRepository` (`Module/Public/Build/Initialize-BrownserveRepository.ps1:96`) or `Update-BrownserveRepository` (`Module/Public/Build/Update-BrownserveRepository.ps1:137`) by hand. No workflow in `bsdev` runs it. "A regeneration" below means one of those manual runs.

### Build

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.build/_init.ps1` | Repository paths; paths wiped and recreated on each run, including `paket.lock` (`:77-79`); modules to import: the three Brownserve modules, Invoke-Build, Pester (`:150-198`); repo name from the directory name at run time (`:64`) | `New-BrownserveInitScript` with the `bsdev` settings (`:702-707`); the `.build/tests` path from `repository_paths_config.json` | The generator, except the `user defined _init steps` section (`:336-353`), which it keeps; empty in `bsdev` | `build.ps1:154` | A regeneration picks up changes to `New-BrownserveInitScript` or the paths config; the maintainer edits the user section |
| `.build/build.ps1` | Build targets, including `BuildImage` (`:28-36`); publish targets `DockerHub`, `GHCR`, `GitHub` (`:59`); owner default `Brownserve-UK` (`:69`); `BinaryName = 'bsdev'` (`:177`); DockerHub and GHCR credential parameters | `bsdev_build_script.ps1.template` with repo name and owner filled in; matches the template exactly | The generator, whole file (`:2107-2124`) | CI workflows; the maintainer | A regeneration picks up a template, repo name or owner change |
| `.build/tasks/build_tasks.ps1` | Rust tasks: `Build`, `CargoTest`, `Package`, `UpdateCargoVersion` (writes `[workspace.package]` in the root `Cargo.toml`, `:316`); container tasks: `BuildImage`, DockerHub and GHCR pushes; `BinaryName` and `ImageName` default to the repo name (`:19`, `:26`), `ImageName` lowercased (`:135`); Docker context defaults to `image` (`:131`) | `bsdev_build_tasks.ps1.template`, no substitutions; matches the template exactly | The generator, whole file. During a staged release, the file itself writes `Cargo.toml`, `Cargo.lock` and `CHANGELOG.md` | `build.ps1`, through Invoke-Build | A regeneration picks up a template change |
| `.build/tests/Basic.Binary.Tests.ps1` | Binary name `bsdev` four times (`:4`, `:8`, `:12`, `:35`); build output path | `rustapp_binary_tests.ps1.template` with repo name filled in. Lines 38-47 add two tests not in the template, added directly by an AI agent that didn't know the file was generated | The generator, whole file (`:2182-2199`); a regeneration would drop lines 38-47 | `Tests` task (`build_tasks.ps1:539`) | A regeneration picks up a template or repo name change; direct edits, as with lines 38-47 |
| `paket.dependencies` | NuGet source; the three Brownserve modules, Invoke-Build, Pester; no versions | `paket_dependencies_config.json`: defaults plus `bsdev` (Pester) | The generator (auto section); keeps the manual section (`:16`), which is empty | `_init.ps1:138` (`dotnet paket install`). `paket.lock` is deleted on every init, so the latest versions are always pulled | A regeneration picks up a config change; the maintainer edits the manual section |
| `nuget.config` | One package source, nuget.org | `dotnet new nugetconfig`, run during generation (`:1083-1087`) | The generator, whenever it differs (`:1283-1310`) | `dotnet` tooling | A regeneration where `dotnet new nugetconfig` output has changed (depends on the installed .NET SDK) |
| `.config/dotnet-tools.json` | Paket `10.3.1` | `dotnet tool install Paket`, run when first generated (`:1109-1118`) | The generator, only if missing (`:1326`). No Dependabot `nuget` entry for `bsdev`; the PowerShell module types have one (`:426`, `:488`) | `_init.ps1:129` (`dotnet tool restore`) | Only a hand edit, or a regeneration after the file is deleted |

### CI workflows

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.github/workflows/builds.yaml` | Runs on PRs to `main`. Change filters for Rust/build paths (`Cargo.toml`, `Cargo.lock`, `*.rs`, `.build/`, `.config/`, `nuget.config`, `:28`) and for `image/` (`:35`); OS matrix (`:49`); repo name `bsdev` (`:59`, `:65`, `:84`, `:90`); build targets `BuildTestAndCheck` (`:67`) and `BuildImage` (`:92`); a gate job named `BuildTestAndCheck` (`:98`); action pins (`:57`, `:82`) | `bsdev_github_builds.yaml.template` with the repo name filled in. Matches apart from the action pins | The generator, whole file (`:1824`, `:1863-1876`); Dependabot (`github-actions`) for the pins | GitHub Actions; Terraform requires a check named `BuildTestAndCheck` (`repos.tf:211`) | A regeneration, which would put the pins back to the template's older SHAs; a Dependabot pin bump |
| `.github/workflows/stage-release.yaml` | Manual trigger with a `release_type` input (`:5-14`); repo name (`:34`, `:48`); Rust toolchain install for `UpdateCargoVersion` (`:39`); target `StageRelease`; CI app secrets (`:28-29`) | `rustapp_github_stage-release.yaml.template`, which `bsdev` shares with `RustApp` (`:749`), with the repo name filled in. Matches apart from the action pin | The generator, whole file; Dependabot for the pins | GitHub Actions (manual dispatch) | A regeneration; a Dependabot pin bump |
| `.github/workflows/release.yaml` | Manual trigger with a `publish_to` input that defaults to GitHub, GHCR, DockerHub (`:5-10`); a matrix of OS and Rust target triples (`:19-25`); targets `Package` and `Release`; artifact name `binary-*` and path `bsdev/.tmp/output/` (`:50-51`, `:80`); `packages: write` for GHCR (`:61`); secrets: CI app (`:68-69`), `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` (`:89-90`), `SLACK_WEBHOOK_BUILD` (`:110`); `GITHUB_TOKEN` for GHCR (`:88`) | `bsdev_github_release.yaml.template` with the repo name filled in. Differs by more than pins: the `publish_to` input and `PublishTo = ${{ inputs.publish_to }}` (`:96`), where the template hard-codes `@('GitHub', 'GHCR', 'DockerHub')` | The generator, whole file; Dependabot for the pins; the maintainer, for `publish_to` (a fix made in place, never carried back to the template) | GitHub Actions (manual dispatch) | A regeneration, which would drop `publish_to` and put the pins back; a Dependabot pin bump |
| `.github/workflows/label-pr.yaml` | Mapping from PR title prefix to changelog label (`:79-90`); labelling for Dependabot PRs (`:93-119`); skips `release/` branches (`:73`); job name `label-pr` | `psmodule_github_label-pr.yaml.template`, no substitutions (`New-BrownserveGitHubLabelPRWorkflow.ps1:11`). Content is identical. Every project type that has workflows gets it (`:409`, `:470`, `:526`, `:613`, `:712`, `:805`) | The generator, whole file (`:1910-1937`); Dependabot could bump the `github-script` pin, which still matches the template | GitHub Actions (`pull_request_target`); Terraform requires a check named `label-pr` (`repos.tf:211`) | A regeneration picks up a template change; a Dependabot pin bump |

**Secrets the workflows read:** see [GitHub settings](#github-settings).

### Dependency tooling

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.github/dependabot.yml` | Three ecosystems, all weekly with a 30-day cooldown: `github-actions` at `/` (`:4-9`), `cargo` at `/` (`:11-16`), `docker` at `/image` (`:18-23`) | `New-BrownserveDependabotConfig` with the `bsdev` updates (`:725-731`). Matches exactly. `RustApp` has the same list without `docker` (`:626-631`) | The generator, whole file, whenever it differs (`:2418-2464`) | Dependabot | A regeneration picks up a change to the `bsdev` list or to `New-BrownserveDependabotConfig` |
| `Cargo.toml` (root) | Workspace members `core` and `cli` (`:2`); version `0.10.0` and edition under `[workspace.package]` (`:5-7`) | Not generated: nothing in the generator or templates produces it | The maintainer; `UpdateCargoVersion` rewrites the version during a staged release (`build_tasks.ps1:308-323`) | Cargo (`Build`, `CargoTest`, `build_tasks.ps1:490-531`); `UpdateCargoVersion`, which fails if there's no `[workspace.package]` `version` (`:316-320`); Dependabot (`cargo`, `/`) | The maintainer adds or removes a crate; each staged release bumps the version |
| `cli/Cargo.toml` | Package `bsdev` and binary `bsdev` (`:2`, `:7`); version and edition taken from the workspace (`:3-4`); dependencies, including `bsdev-core` by path (`:10-17`) | Not generated | The maintainer; Dependabot (`cargo`) for dependency versions | Cargo. The binary name must match `BinaryName`, otherwise `Package` can't find the binary (`build_tasks.ps1:567-571`) | The maintainer changes dependencies or the binary; a Dependabot bump |
| `core/Cargo.toml` | Package `bsdev-core`; version and edition taken from the workspace; dependencies (`:6-11`) | Not generated | The maintainer; Dependabot (`cargo`) | Cargo | Same as `cli/Cargo.toml` |
| `Cargo.lock` | Resolved versions of every crate, including `bsdev` and `bsdev-core` at `0.10.0` (`:148-149`, `:159-160`) | Cargo, from the three manifests | Cargo, when the maintainer builds after a manifest change; Dependabot (`cargo`); `UpdateCargoVersion`, which runs `cargo generate-lockfile` (`build_tasks.ps1:330`). That command rebuilds the lock with the latest compatible version of every dependency | Cargo; the `builds.yaml` change filter (`:28`). It's committed, not ignored (`.gitignore:21`) | Any manifest change; a Dependabot bump; every staged release, which can also move dependency versions |
| `image/Dockerfile` | Base image `archlinux:latest` with no version or digest (`:8`); the full toolset, including Rust (`:22-74`); login user `bsdev` (`:10`, `:118`); files copied in from `image/` (`:91-112`) | Not generated. The generator's Dockerfile handling covers `.devcontainer/` (`:208`), not `image/` | The maintainer | `BuildImage`, through the Docker context `image` (`build_tasks.ps1:131`, `:184`); Dependabot (`docker`, `/image`); the `builds.yaml` `image/` filter (`:35`) | The maintainer changes the image |

Only `dependabot.yml` is generated here; the rest is maintainer-owned. Its `docker` entry is the only difference from `RustApp`.

### Dev environment

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.devcontainer/devcontainer.json` | Name `Ubuntu`, build arg `VARIANT: focal`, `remoteUser: vscode` (`:2-8`, `:23`); the extension list (`:11-19`) | `New-VSCodeDevcontainer` (`Module/Private/VSCode/New-VSCodeDevcontainer.ps1:44-59`). The values are hard-coded, apart from the extensions, which are the same list as `extensions.json` (`:1144`). Matches exactly | The generator, whole file, whenever it differs (`:1527-1578`) | VS Code Dev Containers | A regeneration picks up a change to the extension list or `New-VSCodeDevcontainer` |
| `.devcontainer/Dockerfile` | Ubuntu focal base (`:5-6`); PowerShell (`:15-29`); Rust build dependencies and rustup (`:31-39`). No Docker tooling. Header says manual changes will be lost (`:1`) | `Module/Private/VSCode/devcontainer/Dockerfile_RustApp`, which `bsdev` shares with `RustApp` (`devcontainer_config.json:10-17`). Matches exactly | The generator, whole file (`:1581-1609`). No Dependabot entry covers `.devcontainer/` | `devcontainer.json:7` | A regeneration picks up a template change or a change to the Dockerfile mapping |
| `.vscode/extensions.json` | Seven recommended extensions, including `rust-analyzer` and `even-better-toml` (Rust) and `vscode-docker` (container) | `repository_vscode_extensions.json`: defaults (`:2-23`) plus `bsdev` (`:80-113`). Same set as the config but in a different order, because the generator puts the extensions already in the file first and then adds the config's (`:270`, `:993-994`) | The generator, whole file. It only ever adds: an extension already in the file is never removed | VS Code | A regeneration adds any new extensions from the config; the maintainer adds extensions, which are kept |
| `.vscode/settings.json` | cSpell language and words (`:2-16`); PowerShell formatting settings (`:17-23`) | The `CustomSettings` of the same config entries, merged and sorted alphabetically (`:1006-1054`). Matches the config | The generator, whole file. It deep-merges with the existing settings; the repo's values win unless `-Force` is used (`:1024-1036`). Like extensions, nothing is removed | VS Code | A regeneration adds new settings from the config; the maintainer edits settings, which are kept |
| `.editorconfig` | A default for all files (`:12-16`); sections for PowerShell (`:19-23`), Rust (`:26-30`), TOML (`:33-37`), and Dockerfiles and shell scripts (`:40-44`); a manual section (`:46`), which is empty | `editorconfig_config.json`: defaults (`:2-13`) plus `bsdev` (`:66-115`). Matches exactly. `bsdev`'s list is `RustApp`'s plus the Dockerfile and shell section | The generator, apart from the manual section, which it keeps (`:1155-1182`, `:1617-1659`) | Editors through the EditorConfig extension | A regeneration picks up a config change; the maintainer edits the manual section |

Three merge behaviours: the devcontainer files are replaced whole, `.vscode/*` only adds, and `.editorconfig` keeps a manual section. Because `.vscode/*` only adds, removing a capability today would leave its extensions and settings behind (e.g. `vscode-docker` after `container` is removed).

`.devcontainer/` is an Ubuntu VS Code container for working on the repo. It's unrelated to the `container` capability, which is the Arch image `bsdev` ships from `image/`.

### Repository hygiene

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.gitignore` | Paket files and `.tmp/` (`:6-11`); AI tool directories (`:14-19`); Rust: `target/` and `**/*.rs.bk` (`:22-25`); container: `.docker/` (`:28`); a manual section (`:30`) | `gitignore_config.json`: defaults (`:2-26`) plus `bsdev` (`:50-63`). Matches exactly. `bsdev`'s list is `RustApp`'s plus `.docker/`, which it shares with `WebApp` | The generator, apart from the manual section after `## Manually defined ignores: ##`, which it keeps (`:308-320`, `:1372-1397`). If that marker is missing, the file is reported as unparsable and generation stops unless `-Force` is used (`:319`, `:882-890`) | Git | A regeneration picks up a config change; the maintainer edits the manual section |
| `.markdownlint.json` | `MD013` off; `MD024` siblings only | `markdownlint_config.json`, which is one config for every type, with no per-type entries. Matches exactly | The generator, whole file. It deliberately overwrites local changes "for a consistent gold standard" (`:1704-1748`) | markdownlint (VS Code extension) | A regeneration picks up a config change |

`.docker/` is ignored, but nothing in `bsdev`'s `.build/` or `.github/` creates it. It comes along with the container config entry.

`.markdownlint.json` is the first file deliberately identical across every type, with no local customisation allowed. Neither `rust-app` nor `container` affects it.

### Docs

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `README.md` | What the tool does and the image's toolset (`:9-23`); install one-liners with owner and repo baked into the URLs (`:31`, `:36`); command usage; building needs Rust and PowerShell, and runs `BuildTestAndCheck` (`:107-113`) | Not generated: nothing in the generator or templates produces it | The maintainer | People, on GitHub. Nothing in `.build/`, `.github/` or `scripts/` reads it | The maintainer documents a change |
| `CHANGELOG.md` | Keep a Changelog header and a `## Release` heading (`:1-8`); one entry per release, with owner and repo in every link (`:10` onwards) | Header: `New-BrownserveChangelogHeader` (`Module/Private/Build/New-BrownserveChangelogHeader.ps1:7-20`), which also writes a `v0.0.0` placeholder that the first staged release replaces. Entries: `New-BrownserveChangelogEntry -Auto`, built from merged PRs and their labels (`build_tasks.ps1:344-368`) | The generator, only if missing (`:1667-1686`); `UpdateChangelog` during a staged release (`build_tasks.ps1:380-392`) | `GetReleaseHistory` for the current version (`build_tasks.ps1:261-272`); `PublishRelease` for the version and release notes (`:604-608`) | Every staged release |
| `LICENSE` | MIT, `Copyright (c) 2026 Brownserve-UK` | `New-SPDXLicense` (`Module/Public/Build/New-SPDXLicense.ps1`): fetched from the SPDX list on GitHub, with year and owner filled in (`:78`). The `bsdev` type sets `MIT` (`:708`) | The generator, only if missing; never overwritten "for legal reasons" (`:1688-1702`) | People; GitHub's licence detection | Only a hand edit |
| `CLAUDE.md` | Repo layout, how it works, build commands, conventions for AI agents. Restates scaffold facts: binary must be `bsdev` and pass the Pester contract (`:130-132`); `[workspace.package]` version bumped by release tooling (`:11-12`); image published to GHCR (`:46`) | Not generated | The maintainer (and agents working on the repo) | AI coding agents. Committed; `.claude/` is ignored but `CLAUDE.md` isn't (`.gitignore:16`) | The maintainer or an agent updates it |
| `.github/CONTRIBUTING.md` | Prerequisites: Rust toolchain and PowerShell 7 (`:7-8`); `cargo build`/`cargo test` and `BuildTestAndCheck` (`:12-24`); signed commits; the Conventional Commits prefix table (`:36-42`) | `RustApp_github_contributing.md.template`, which `bsdev` shares with `RustApp` (`:734`), no substitutions. Matches exactly | The generator, whole file, whenever it differs (`:1946-1991`) | People, on GitHub | A regeneration picks up a template change |
| `.github/pull_request_template.md` | Repo name (`:1`); links to CONTRIBUTING and the org `CODE_OF_CONDUCT.md` with owner and repo filled in (`:12-13`); `cargo build` and `cargo test` checklist items (`:14-15`) | `RustApp_github_pull_request_template.md.template` with `REPO_NAME` and `OWNER` filled in (`:736-740`, `:2009-2013`). Matches | The generator, whole file, whenever it differs (`:1993-2048`) | GitHub, when a PR is opened | A regeneration picks up a template, repo name or owner change |

Three write behaviours: CONTRIBUTING and the PR template are replaced whole; `CHANGELOG.md` and `LICENSE` are only created if missing; `README.md` and `CLAUDE.md` aren't generated at all.

Only `rust-app` shows up in the generated docs (CONTRIBUTING prerequisites, both files' cargo commands). Neither generated doc mentions `container`: there's no `BuildImage` or Docker step in either. The image only appears in the maintainer-owned `README.md` and `CLAUDE.md`.

`New-SPDXLicense` runs on every regeneration (`:1216-1222`) even though its output is only used when `LICENSE` is missing, so every regeneration needs to reach GitHub.

### Install scripts

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `scripts/install.sh` | Owner, repo and binary name (`:7-9`), with the binary set to the repo name; the latest release tag from the GitHub API (`:11-13`); OS/arch to target triple: Linux `x86_64` and macOS `arm64` only (`:23-40`); asset name `<binary>-<tag>-<triple>.tar.gz` (`:42`); install paths (`:53-61`) | `rustapp_install.sh.template` with `OWNER` and `REPO_NAME` filled in (`:770-776`, `:2229-2236`), which `bsdev` shares with `RustApp` (`:670-674`). Matches | The generator, whole file, whenever it differs (`:2218-2280`) | People, through the one-liner in `README.md:31`, which fetches it from `main` | A regeneration picks up a template, repo name or owner change |
| `scripts/install.ps1` | Owner, repo and binary name (`:13-15`); the latest release tag from the GitHub API (`:17-18`); a single target `x86_64-pc-windows-msvc` (`:25`); asset name `<binary>-<tag>-<triple>.zip` (`:26`); install paths and PATH update (`:42-62`) | `rustapp_install.ps1.template`, same substitutions (`:777-781`). Matches | The generator, whole file, whenever it differs | People, through the one-liner in `README.md:36` | Same as `install.sh` |

Neither script is touched by `container`. They rely on what the `rust-app` capability's release produces: `Package` names archives `<BinaryName>-v<version>-<triple>` with `.zip` on Windows and `.tar.gz` elsewhere (`build_tasks.ps1:577`, `:584`), and `PublishRelease` uploads them as release assets (`:627-649`). The scripts have no check that these names agree; a mismatch only shows up when someone runs the installer.

The template fills `BINARY` from the repo name, but the build takes `BinaryName` as a parameter (`build.ps1:177`, default repo name at `build_tasks.ps1:19`). If the two ever differ, the installers would look for an asset that doesn't exist.

### Generator

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.brownserve_repository_manifest` | `RepositoryType: bsdev` and `ManifestVersion: 1.0.0` (`:2-3`) | Built in code, with no config file (`:370-373`). `RepositoryType` is the `-ProjectType` passed to `Initialize-BrownserveRepository` (`:14-15`, `:98`), one of the `BrownserveRepoProjectType` enum values (`Module/Private/Classes.ps1:564-573`) | The generator, whole file, whenever it differs (`:1245-1280`) | `Update-BrownserveRepository`, which takes the project type from it (`:81-95`, `:121`); `Compare-BrownserveRepository`, which refuses a different type without `-Force` (`:222-246`); `Get-BrownserveRepositoryPaths` (`:30-43`), which nothing in the PSTools repos, `bsdev` or Terraform calls | Only by running `Initialize-BrownserveRepository -Force` with a different type |

This is the only place a repository says what it is. Everything generated in the groups above follows from this one value plus the generator's built-in settings for each type.

It doesn't record the owner or repo name. Each run gets them again: the owner from the `-Owner` default `Brownserve-UK` (`Update-BrownserveRepository.ps1:14`), and the repo name from the directory name unless `-RepoName` is passed (`Compare-BrownserveRepository.ps1:42-46`, `:1995-1998`). Running `Update-BrownserveRepository` from a clone in a directory with a different name would bake that name into every generated file that uses it.

`ManifestVersion` is written but nothing reads it.

### GitHub settings

These are org and repo settings, not files in `bsdev`. The maintainer writes the Terraform-managed ones by hand in the Terraform repo, and GitLab CI applies them on merge to `main` (`Terraform/.gitlab-ci.yml:130-147`). Nothing generates them and nothing in `bsdev` writes them. The others were set by hand in GitHub.

One row per setting, showing what in `bsdev` has to agree with it.

| Setting | Stated in | Referred to in `bsdev` | Capability |
| --- | --- | --- | --- |
| Required checks `BuildTestAndCheck`, `label-pr` (strict) | `repos.tf:211`; `repository.tf:56-62` | Job names in `builds.yaml:98` and `label-pr.yaml` | None. The gate job covers both the Rust and image builds (`builds.yaml:97-120`) |
| Issue labels, `application` set, authoritative | `repos.tf:207`; `issues.tf:2-3`, `:8-97`, `:153` | Labels applied by `label-pr.yaml:79-90`, `:93-119`; changelog grouping | None |
| CI app install, `BROWNSERVE_CI_APP_ID` and `BROWNSERVE_CI_APP_PRIVATE_KEY` | `apps.tf:51-54`, `:84-96` | `stage-release.yaml:28-29`, `release.yaml:68-69` | None |
| `SLACK_WEBHOOK_BUILD` | `secrets.tf:72-77`, `:178-183` (every repo) | `release.yaml:110` | None |
| `GH_TOKEN_RELEASE`, `GH_TOKEN_STAGE_RELEASE`, `GPG_KEY_AUTOMATED_BUILD` | `secrets.tf:131` | Not read | None |
| `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` | Set by hand in repo settings | `release.yaml:89-90`; `DockerHub` in `publish_to` (`release.yaml:9`, `build.ps1:59`) | `container` |
| GHCR push | Not in Terraform; the workflow grants `packages: write` (`release.yaml:61`) to `GITHUB_TOKEN` (`:88`) | `GHCR` in `publish_to` | `container` |
| Push restricted to Build Automation; Codeowners bypass PR reviews; signed commits | `repos.tf:208-209`; `teams.tf:15`, `:44`; `variables.tf:35` (default) | Not referred to | None |
| Code owner reviews required | `repos.tf:212` | No `CODEOWNERS` file | None |

Nothing in Terraform depends on `rust-app` or `container`. `container` shows up only in settings that are outside Terraform: the hand-set Docker Hub secrets, and GHCR, which works off the workflow's own token. So today, adding or removing a capability changes nothing in Terraform.

Every link between a setting and `bsdev` is by name only (check names, label names, secret names), and nothing checks that the two sides agree. The `removed`/`removal` mismatch is one that has already drifted.

### Repeated information

Information stated in more than one place. Groups that cover it are in brackets.

- **Repo name** (Build, CI workflows, Docs, Install scripts, Generator): worked out at run time in `_init.ps1:64`. Everywhere else the generator bakes it in from the directory name (`Compare-BrownserveRepository.ps1:42-46`): `build.ps1`, `Basic.Binary.Tests.ps1`, nine times in the workflows, the PR template (`:1`), both install scripts, the `README.md` install URLs (`:31`, `:36`) and every `CHANGELOG.md` entry link.
- **Owner `Brownserve-UK`** (Build, Docs, Install scripts, Generator, GitHub settings): `build.ps1:69`, `README.md:31`, `:36`, `CHANGELOG.md` links, `LICENSE`, the PR template (`:12-13`), `install.sh:7`, `install.ps1:13`, the `-Owner` default (`Update-BrownserveRepository.ps1:14`) and `provider.tf:32`.
- **Binary name** (Build, Dependency tooling, Install scripts, Docs): `build.ps1:177`, `Basic.Binary.Tests.ps1` (`:4`, `:8`, `:12`, `:35`), the `build_tasks.ps1:19` default, `cli/Cargo.toml:7` (which must match `BinaryName`), both install scripts (taken from the repo name) and `CLAUDE.md:130-132`.
- **Version** (Dependency tooling, Docs): `Cargo.toml:6`, `Cargo.lock` (`:148-149`, `:159-160`) and the latest `CHANGELOG.md` entry (`:10`). `UpdateCargoVersion` keeps them in step; `CLAUDE.md:11-12` describes it.
- **Docker context `image/`** (CI workflows, Dependency tooling): the `build_tasks.ps1:131` default, `builds.yaml:35` and `dependabot.yml:19`.
- **Rust target triples** (CI workflows, Install scripts): `release.yaml:21-25`, `install.sh:26`, `:32` and `install.ps1:25`. The installers each cover a subset; all match today.
- **Release asset naming** (Install scripts): `build_tasks.ps1:577`, `:584`, `install.sh:42` and `install.ps1:26`.
- **Publish destinations** (CI workflows): `release.yaml:9`, the `ValidateSet` in `build.ps1:59` and a hard-coded list in the release template.
- **Build target names** (CI workflows): the workflows call `BuildTestAndCheck`, `BuildImage`, `Package`, `Release` and `StageRelease`, which must exist in `build.ps1:28-36`.
- **Build commands** (Docs): `cargo build`, `cargo test` and `BuildTestAndCheck` in `README.md`, `CLAUDE.md`, `CONTRIBUTING.md` and the PR template.
- **Required check names** (CI workflows, GitHub settings): the `BuildTestAndCheck` job (`builds.yaml:98`), the `label-pr` job and `repos.tf:211`.
- **Changelog labels** (CI workflows, Docs, GitHub settings): `label-pr.yaml:79` and `issues.tf:8-97`. `New-BrownserveChangelogEntry -Auto` sorts entries by the labels `label-pr.yaml` applies (confirmed by the maintainer). They disagree (Q1), and the mismatch reaches `CHANGELOG.md`.
- **Conventional Commits prefix table** (Docs): `CONTRIBUTING.md:36-42`, the title mapping in `label-pr.yaml:79-90`, and the "label missing" comment the workflow posts (`label-pr.yaml:171-184`).
- **Release-participating repos** (GitHub settings): `secrets.tf:125-134`, `apps.tf:34-63` and `teams.tf:10-47`. Three hand-maintained lists that mostly overlap; `bsdev` is in all three.
- **Project type** (Generator): `.brownserve_repository_manifest:2`, and the `bsdev` branch of the generator's type switch (`:690-783`).
- **Extension list** (Dev environment): `extensions.json` and `devcontainer.json:11-19`, written from one list in the same run (`:1144`).
- **Ubuntu focal** (Dev environment): `devcontainer.json:5`, `.devcontainer/Dockerfile:5` and the `ubuntu/20.04` URL (`:19`).
- **Rust and container dev config** (Dev environment): each shows up in three places: extensions, `.editorconfig` sections, and the devcontainer (Rust toolchain only).
- **Ephemeral paths** (Repository hygiene): `.tmp/` and `paket.lock` are ignored in `.gitignore` and wiped and recreated by `_init.ps1:77-79`.
- **`Cargo.lock` committed** (Repository hygiene, Dependency tooling): `.gitignore:21`.
- **PowerShell formatting settings** (Dev environment): five type entries in `repository_vscode_extensions.json` (`:31-39`, `:60-70`, `:93-104`, `:115-126`, `:137-148`). Generator-side, not in `bsdev`.

### Extra inventory: `docs-astro`

No repository uses Astro docs (confirmed by the maintainer). This is what the generator would write, recorded only so Trace B has a starting point. `ai-skills` is a skills repo but was never generated: it has only `README.md` and `skills/`.

Astro isn't its own switch. Only the `SkillsRepo` type turns it on (`:810`; default off at `:161`), and its parts are mixed into the skills templates and config.

| Thing | Group | Holds | How the generator writes it |
| --- | --- | --- | --- |
| `pages/package.json` | Docs | Name `<repo>-docs`, `astro ^7.3.5`, Node `>=22.12.0` | Only if missing (`:2383-2394`), repo name filled in |
| `pages/astro.config.mjs` | Docs | Site URL `https://<owner lowercase>.github.io/<repo>` | Only if missing, owner and repo filled in (`:2379-2382`) |
| `pages/src/pages/index.astro` | Docs | Repo name as title; "Documentation for our agent skills" (`skillsrepo_astro_index.astro.template:14`) | Only if missing |
| `pages` path (`BrownserveRepoPagesDirectory`) | Build | Path set by `_init.ps1` | `repository_paths_config.json:131-136`, through `_init.ps1` |
| `BuildDocs` task | Build | `npm install` and `npm run build` in `pages/` (`skillsrepo_build_tasks.ps1.template:373-385`), part of `Build` (`:391`) | Whole file, in the skills build tasks |
| `builds.yaml`, `pages/` filter and Node setup | CI workflows | `pages/` in the change filter (`skillsrepo_github_builds.yaml.template:26`); `setup-node` with Node `22` (`:46-50`) | Whole file, in the skills builds template |
| `release.yaml`, `deploy-docs` job | CI workflows | Runs after `release`, builds with npm directly, force-pushes `pages/dist` to `gh-pages` with `GITHUB_TOKEN` and `contents: write` (`skillsrepo_github_release.yaml.template:62-98`) | Whole file, in the skills release template |
| `dependabot.yml`, `npm` at `/pages` | Dependency tooling | Weekly, 30-day cooldown | `:822`, whole file |
| `.gitignore` entry | Repository hygiene | `node_modules/`, `pages/dist/`, `pages/.astro/` | `gitignore_config.json:64-73`, the whole `SkillsRepo` entry |
| `CONTRIBUTING.md`, "Documentation site" section | Docs | `cd pages`, `npm install`, `npm run dev` (`SkillsRepo_github_contributing.md.template:12-20`) | Whole file, in the skills template |
| PR template checklist item | Docs | "site still builds if `pages/` was changed" (`SkillsRepo_github_pull_request_template.md.template:15`) | Whole file, in the skills template |
| GitHub Pages | GitHub settings | `legacy` build type from the `gh-pages` branch, per repo (`modules/github-brownserve_repo/variables.tf:127-143`) | Terraform. Set for PSTools and the three modules (`repos.tf:35`, `:145`, `:168`, `:191`), not for `bsdev` (`:200-214`) or `ai-skills` (`:237`) |

Astro adds nothing to VS Code extensions, `.editorconfig`, the devcontainer (`SkillsRepo` has none, and no devcontainer installs Node) or Paket.

- **Can't be added on its own.** The task, workflow, CONTRIBUTING and PR template parts are written into the skills templates, not switched on separately, so the generator can't give Astro docs to any other type.
- **Built two ways.** PR checks build the site through `BuildDocs`; `deploy-docs` builds it again with its own npm steps (`skillsrepo_github_release.yaml.template:84-85`). The deployed site isn't built by the code the PR check ran.
- **`Release` doesn't build the docs.** It runs `CheckPublishingParameters, SetReleaseVariables, PublishRelease` (`skillsrepo_build_tasks.ps1.template:514`); only `deploy-docs` does.
- **`pages/` is shared with MkDocs.** The MkDocs scaffold writes to `pages/` too (`:2289`), and the PowerShell modules use it today, so the two docs capabilities can't sit together or be swapped without a clash.
- **Site URL is set once and has to match Terraform.** `astro.config.mjs` is only written if missing, so a repo rename or owner change leaves it wrong. The site only goes live if Terraform has a `pages` block for the repo.
- **Node version in three places:** `22` in both workflow steps and `>=22.12.0` in `package.json`.
- **Versions.** No lock file is scaffolded and CI runs `npm install`. The template's `^7.3.5` only affects new repos; after that, Dependabot `npm` takes over.

## Phase 2: Change traces

Complete.

### Today's map

References for each row are in the matching Phase 1 table.

**Sources**

| Source | What it is |
| --- | --- |
| **Generator** | PSBuildTools templates, config files and code, selected by the `bsdev` project type. Repo name and owner are filled in at run time. |
| **Maintainer** | Anything written by hand in `bsdev`, including by AI agents. |
| **Upstream** | New releases of actions, crates and base images. |
| **Cargo** | Dependency resolution from the `Cargo.toml` files. |
| **npm** | Dependency resolution from `package.json` (`docs-astro` only). |
| **Release history** | The previous version, the release type and the PRs merged since. |
| **.NET SDK** | `dotnet` commands the generator runs. |
| **SPDX list** | Licence texts fetched from GitHub. |
| **Terraform** | The Terraform repo. |

**Routes**

Every Regen route is a manual run of `Initialize-` or `Update-BrownserveRepository`.

| Route | What it does |
| --- | --- |
| **Regen** | The generator replaces the whole file. |
| **Regen (section)** | The generator replaces everything except the file's manual section. |
| **Regen (add-only)** | The generator adds missing entries and never removes any. |
| **Regen (if missing)** | The generator writes the file only if it doesn't exist. |
| **Hand edit** | Someone edits the file in `bsdev`. |
| **Dependabot PR** | Dependabot opens a PR. |
| **Cargo build** | Cargo rewrites the lock file when a build sees a manifest change. |
| **npm install** | npm rewrites the lock file (`docs-astro` only). |
| **Staged release** | The `StageRelease` tasks write the file. |
| **Terraform apply** | GitLab CI applies Terraform on merge to `main`. |
| **Hand-set in GitHub** | Someone sets it in the repository settings on GitHub. |

**Build**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `_init.ps1`, generated part | Generator | Regen (section) |
| `_init.ps1`, user section (empty) | Maintainer | Hand edit |
| `build.ps1` | Generator | Regen |
| `build_tasks.ps1` | Generator | Regen |
| `Basic.Binary.Tests.ps1`, template tests | Generator | Regen |
| `Basic.Binary.Tests.ps1:38-47` ⚠ T2 | Maintainer | Hand edit |
| `paket.dependencies`, auto section | Generator | Regen (section) |
| `paket.dependencies`, manual section (empty) | Maintainer | Hand edit |
| `nuget.config` | .NET SDK | Regen |
| `.config/dotnet-tools.json` ⚠ T4 | .NET SDK | Regen (if missing) |

**CI workflows**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `builds.yaml` | Generator | Regen |
| `stage-release.yaml` | Generator | Regen |
| `release.yaml` | Generator | Regen |
| `release.yaml`, `publish_to` input ⚠ T2 | Maintainer | Hand edit |
| `label-pr.yaml` | Generator | Regen |
| Action pins in all four ⚠ T1 | Upstream; Generator | Dependabot PR; Regen |

**Dependency tooling**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `dependabot.yml` | Generator | Regen |
| Root `Cargo.toml`, members and edition | Maintainer | Hand edit |
| Root `Cargo.toml`, `[workspace.package]` version | Release history | Staged release |
| `cli/` and `core/` `Cargo.toml`, packages, binary name, dependency list | Maintainer | Hand edit |
| `cli/` and `core/` `Cargo.toml`, dependency versions | Upstream | Dependabot PR |
| `Cargo.lock` ⚠ T3 | Cargo | Cargo build; Dependabot PR; Staged release |
| `image/Dockerfile` | Maintainer | Hand edit |
| `image/Dockerfile`, base image tag | Upstream | Dependabot PR (may do nothing, Q2) |

**Dev environment**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `devcontainer.json` | Generator | Regen |
| `.devcontainer/Dockerfile` | Generator | Regen |
| `extensions.json`, config entries | Generator | Regen (add-only) |
| `extensions.json`, maintainer additions (none today) | Maintainer | Hand edit |
| `settings.json`, config entries | Generator | Regen (add-only) |
| `settings.json`, maintainer edits (none today) | Maintainer | Hand edit |
| `.editorconfig`, generated sections | Generator | Regen (section) |
| `.editorconfig`, manual section (empty) | Maintainer | Hand edit |

**Repository hygiene**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.gitignore`, generated sections | Generator | Regen (section) |
| `.gitignore`, manual section (`image/proto/node_modules/`) | Maintainer | Hand edit |
| `.markdownlint.json` | Generator | Regen |

**Docs**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `README.md` | Maintainer | Hand edit |
| `CHANGELOG.md`, header | Generator | Regen (if missing) |
| `CHANGELOG.md`, entries | Release history | Staged release |
| `LICENSE` | SPDX list | Regen (if missing) |
| `CLAUDE.md` | Maintainer | Hand edit |
| `CONTRIBUTING.md` | Generator | Regen |
| `pull_request_template.md` | Generator | Regen |

**Install scripts**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `install.sh` | Generator | Regen |
| `install.ps1` | Generator | Regen |

**Generator**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.brownserve_repository_manifest` ⚠ T7 | Maintainer (the `-ProjectType` argument) | Regen (`Initialize-BrownserveRepository`) |

**GitHub settings**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Required checks, labels, branch protection | Terraform | Terraform apply |
| CI app install and its secrets | Terraform | Terraform apply |
| `SLACK_WEBHOOK_BUILD` | Terraform | Terraform apply |
| `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` | Maintainer | Hand-set in GitHub |
| GHCR push access | Generator | Regen (`packages: write` in `release.yaml`) |

**`docs-astro` (hypothetical, generator only)**

No repo uses it; see [Extra inventory: `docs-astro`](#extra-inventory-docs-astro) for references.

| Group | Thing | Comes from | Gets there by |
| --- | --- | --- | --- |
| Docs | `pages/` scaffold (`package.json`, `astro.config.mjs`, `index.astro`) ⚠ T5 | Generator | Regen (if missing) |
| Docs | `pages/` content after scaffolding | Maintainer | Hand edit |
| Dependency tooling | `package.json` dependency versions | Upstream | Dependabot PR |
| Dependency tooling | `package-lock.json` (not scaffolded; only if the maintainer commits one) | npm | npm install; Dependabot PR |
| Build | `pages` path in `_init.ps1` | Generator | Regen (section) |
| Build | `BuildDocs` in `build_tasks.ps1` ⚠ T6 | Generator | Regen |
| CI workflows | `builds.yaml`, `pages/` filter and Node setup | Generator | Regen |
| CI workflows | `release.yaml`, `deploy-docs` job ⚠ T6 | Generator | Regen |
| CI workflows | `setup-node` pins ⚠ T1 | Upstream; Generator | Dependabot PR; Regen |
| Dependency tooling | `dependabot.yml`, `npm` entry | Generator | Regen |
| Repository hygiene | `.gitignore` entry | Generator | Regen (section) |
| Docs | CONTRIBUTING section, PR template item | Generator | Regen |
| GitHub settings | GitHub Pages (`legacy`, `gh-pages`) ⚠ T5 | Terraform | Terraform apply |

Not mapped, because they aren't committed: `paket.lock`, `packages/`, `.tmp/`, `target/`; for `docs-astro`, `node_modules/`, `pages/dist/` and `pages/.astro/`. The `gh-pages` branch isn't mapped either: `deploy-docs` rebuilds and force-pushes it on every release rather than it being committed from `main`.

**Problems**

T1 to T7 are in the [Register](#register).

### Proposed map

Filled in by the traces. Group names match today's map so the two line up. References are to the research docs: [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md) (UDF), [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) (IBT), [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md) (GHA) and [Paket](./2026-09-30%20-%20Paket.md).

Unlike today's map, a row is also given to anything that replaces a file committed today, even if the replacement isn't committed (e.g. the shared tasks, restored into `packages/`).

**Sources**

| Source | What it is |
| --- | --- |
| **Maintainer** | Anything written by hand in the repo, including the answers given to Copier. |
| **Template** | The Copier template repo, released with version tags (UDF `:133`). Its own Dependabot bumps the version references it renders (3.2). |
| **Task package** | The shared build tasks, one base script per capability (IBT `:85`), plus the stock Pester tests, which read the binary name from the project config (UDF `:92`). |
| **Shared workflows** | The Tier 2 reusable workflows, which call the Tier 1 actions (GHA `:53-79`). |
| **Upstream** | New releases of packages (the task package, the Brownserve modules, Invoke-Build, Pester), of the shared workflows, and of crates and base images. |
| **NuGet** | Dependency resolution from the dependency manifest. Same role as Cargo. |
| **Cargo** | Dependency resolution from the `Cargo.toml` files. |
| **Release history** | The previous version, the release type and the PRs merged since. |
| **Terraform** | The repo's module call in the Terraform repo. |

**Routes**

Every `copier copy` route, apart from `copier copy` (scaffold), is kept current afterwards by `copier update`.

| Route | What it does |
| --- | --- |
| **`copier copy`** | Runs once, when the repo is set up. Copier asks the maintainer its questions, fills in the template, and writes the files plus `.copier-answers.yml` (UDF `:127`, `:266`). |
| **`copier copy` (scaffold)** | Written once at set-up; template updates never touch it again (`_skip_if_exists`, UDF `:138`). |
| **`copier update`** | Re-renders the template with the recorded answers, or changed ones, and 3-way merges the result (UDF `:127`). The maintainer runs it to change an answer; the template sync runs it with `--defaults` for each template release (UDF `:141`, `:235`). |
| **Copier task** | A command the template runs after rendering, e.g. `dotnet add package` (UDF `:256`). |
| **Package restore** | `_init.ps1` restores packages into `packages/` (not committed), at the versions in the lock file (Paket `:93`). |
| **Workflow call** | GitHub runs the shared workflow at the version the stub pins (GHA `:46-47`, `:103`). Nothing is copied into the repo. |
| **Hand edit** | Someone edits the file in the repo. |
| **Dependabot PR** | Dependabot opens a PR. |
| **Cargo build** | Cargo rewrites the lock file when a build sees a manifest change. |
| **Staged release** | The task package's `StageRelease` tasks write the file, run through the `stage-release` shared workflow. |
| **Dev container build** | VS Code pulls the image and any Features at the version the stub references. Nothing is copied into the repo. |
| **Repo creation** | When Terraform creates the repo, GitHub writes these files into its first commit. Runs once. |

**Build**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Shared tasks (today's `build_tasks.ps1`) | Task package | Package restore |
| Shared tasks, `docs-astro` base script (today's `BuildDocs`) | Task package | Package restore |
| Stock tests (today's `Basic.Binary.Tests.ps1`, apart from lines 38-47) | Task package | Package restore |
| Bootstrap (`build.ps1`, `_init.ps1`) | Template | `copier copy` |
| Project build script, `Extends` list ⚠ A2 | Not settled | Not settled |
| Project build script, project-only tasks (none in `bsdev`) | Maintainer | Hand edit |
| Project tests (today's `Basic.Binary.Tests.ps1:38-47`) | Maintainer | Hand edit |
| Dependency manifest, scaffold | Template | `copier copy` (scaffold) |
| Dependency manifest, package list ⚠ A3 | Template | Copier task |
| Dependency manifest, versions | Upstream | Copier task (first version); Dependabot PR |
| Dependency manifest, lock file | NuGet | Copier task; Dependabot PR |
| `nuget.config` | Template | `copier copy` |

References: shared tasks and base scripts (IBT `:85`, `:111-115`); stock and project tests (UDF `:92`, IBT `:143`); bootstrap (UDF `:91`); project build script `.build/project.build.ps1` (IBT `:101`, `:141`); dependency manifest (Paket `:70-93`, UDF `:255-256`); `nuget.config` (UDF `:98`).

Versions and the lock file each have two routes, but at different times: the Copier task runs once at set-up, and Dependabot acts after that. Local builds aren't a third route, because `dotnet restore --locked-mode` fails rather than rewriting the lock (Paket `:93`, `:98`; confirmed, E7), as long as `_init.ps1` always passes `--locked-mode`: a plain restore rewrites the lock without warning. The Dependabot route needs a `nuget` entry in `dependabot.yml`, covered under Dependency tooling.

The `docs-astro` base script is the "docs site build" (IBT `:117`). Today's `pages` path in `_init.ps1` becomes the docs path, a project config setting (IBT `:142`), covered by the Project config row under Generator. `docs-astro` adds nothing to the dependency manifest: it needs Node and npm, not a NuGet package.

Retired: `paket.dependencies`, and the Paket entry in `.config/dotnet-tools.json` (Paket `:170`). Paket is the only entry in `bsdev`'s file (see the Phase 1 Build table), so the whole file goes.

**CI workflows**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Shared workflow logic (today's jobs: matrices, build steps, gate job, artifacts, Slack) | Shared workflows | Workflow call |
| Shared workflow logic, docs deploy (today's `deploy-docs`) ⚠ T6 | Shared workflows | Workflow call |
| Shared workflow logic, Node setup (version from `engines.node`, 3.7) | Shared workflows | Workflow call |
| Stubs (`ci`, `pr-checks`, `stage-release`, `release`) | Template | `copier copy` |
| `release` stub, `publish_to` input ⚠ A5 | Template | `copier copy` |
| Template sync stub | Template | `copier copy` |
| Stub pins | Template | `copier copy` |

References: tiers and stub contents (GHA `:53-64`, `:85-88`, `:108`); stub ownership, template including the pin (3.2; differs from UDF `:262`); lifecycle workflows (GHA `:119-121`, D3); `label-pr` as its own workflow or folded into `pr-checks` (GHA D7, `:180`); template sync stub (UDF `:235`). Inputs reach the build as environment variables (IBT `:170`), which removes the script injection in today's `publish_to` (GHA `:32`).

- **Repo name:** the shared workflow does the checkout, so the stubs don't need it. Whether the checkout still needs a folder named after the repo is Q5.
- **Required checks:** through a reusable workflow a check is named `<caller job> / <called job>` (GHA `:168`, V6 `:191`). Covered under GitHub settings.
- **Dependabot:** the repo's `github-actions` entry skips the stubs with `exclude-paths` (E21). Brownserve refs' grouping and cooldown exclusion (GHA `:139`) move to the template repo's `dependabot.yml` (3.2). Covered under Dependency tooling.
- **`docs-astro` deploy:** either Tier 1 per generator or `actions/deploy-pages` (GHA `:132`). The stubs' `capabilities` input switches it on, and the `ci` stub's path filter carries the docs path (GHA `:128`); both are covered by the stubs row.
- **Go-live:** a docs-only deploy trigger is Q10.

**Dependency tooling**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `dependabot.yml` | Template | `copier copy` |
| Root `Cargo.toml`, members and edition ⚠ A6 | Maintainer | Hand edit |
| Root `Cargo.toml`, `[workspace.package]` version | Release history | Staged release |
| `cli/` and `core/` `Cargo.toml`, packages, binary name, dependency list ⚠ A6 | Maintainer | Hand edit |
| `cli/` and `core/` `Cargo.toml`, dependency versions | Upstream | Dependabot PR |
| `Cargo.lock` (CI builds with `--locked`, 3.8) | Upstream; Release history; Maintainer | Dependabot PR; Staged release (workspace version only); Local cargo build |
| `image/Dockerfile` ⚠ A6 | Maintainer | Hand edit |
| `image/Dockerfile`, base image tag | Upstream | Dependabot PR (may do nothing, Q2) |
| `package.json`, dependency versions ⚠ B5 | Template (first version); Upstream | `copier copy` (scaffold); Dependabot PR |
| `package.json`, `engines.node` (a major, read by CI, 3.7) | Template (first version); Maintainer | `copier copy` (scaffold); Hand edit |
| `package-lock.json` (committed, CI runs `npm ci`, 3.8) | Upstream; Maintainer | Dependabot PR; Local `npm install` |

References: `dependabot.yml` is class 4, owned by the template (UDF `:79`, `:98`, `:262`), rendered from the answers. Its entries:

- `github-actions` at `/`, only for workflows the template doesn't render; `exclude-paths` lists the stubs (3.2, E21).
- `nuget` at the dependency manifest's folder, new (Paket `:97`, `:119`, `:161`).
- `cargo` at `/`, from `rust-app`.
- `docker` at the Docker context, from `container` (UDF `:134`).
- `npm` at the docs path, from `docs-astro` (today `/pages`, `Compare-BrownserveRepository.ps1:822`).

No entry covers the dev container reference: the template owns it (3.2).

Brownserve refs (`Brownserve-UK/*` actions, `Brownserve.*` packages) are grouped into one PR and excluded from the cooldown (GHA `:139`, Paket `:161`): actions in the template repo's `dependabot.yml` (3.2), packages in each repo's. Without that, a Tier 1 fix could take two 30-day cooldowns to arrive. Confirmed for actions, provided `exclude` matches the case in `uses:` (E12); not run for NuGet (Paket V2 `:189`).

No research doc distributes the `Cargo.toml` files, `Cargo.lock` or `image/Dockerfile`. `UpdateCargoVersion` moves into the task package unchanged (IBT `:38`, `:114`), so T3 carries over and keeps its ID. 3.8 fixes it there.

- **Local edits to `dependabot.yml`:** the file is owned by the template (UDF `:79`), but the merge keeps a maintainer's additions: whole entries below a marker at the end of `updates:`, and edits inside a template entry until the template changes it (3.3). Per-repo ignores can use `@dependabot ignore` instead (E26). Removal is covered in Trace C.
- **Ecosystem labels:** `nuget` adds a third ecosystem with no Terraform label (Q3). Covered under GitHub settings.

**Dev environment**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `devcontainer.json` stub | Template | `copier copy` |
| Dev container reference (base image tag and Feature versions, 3.6) | Template | `copier copy` |
| Dev container toolset: upstream Features on a stock base image (3.6) | Upstream | Dev container build |
| `extensions.json`, template entries | Template | `copier copy` |
| `extensions.json`, maintainer additions (below the marker, 3.3) | Maintainer | Hand edit |
| `settings.json`, template settings (including cSpell) | Template | `copier copy` |
| `settings.json`, maintainer edits (below the marker, 3.3) | Maintainer | Hand edit |
| `.editorconfig`, template sections (same in every repo, 3.5) | Template | `copier copy` |

References: the devcontainer files become class 1 plus a class 4 stub, through published images (Dependabot `docker`) or dev container Features (Dependabot `devcontainers`) (UDF `:94`, D4 `:283`). After 3.2 the template owns the reference, and only Features have a Dependabot route to bump it there (E22). 3.6 chose upstream Features, so no repo keeps a `.devcontainer/Dockerfile`. `.editorconfig` is class 4 (UDF `:98`). `extensions.json` and `settings.json` are class 5 (UDF `:99`). cSpell words are class 3, since `import` can reach a shared list on disk (UDF `:97`, V6 `:298`, E9). If CI checks spelling, the stub is a `cspell.json`, as the CLI doesn't read `settings.json`, and the template's `settings.json` points the editor's "add word" at it (E9). `.editorconfig` sections don't follow the capabilities: the template's part is the union of every capability's sections, the same in every repo (3.5).

- **Manual sections:** `.editorconfig` keeps a marker comment, which nothing parses, and local rules go below it (3.3). `extensions.json` and `settings.json` gain one. `bsdev`'s `.editorconfig` section is empty, so it has no maintainer row.
- **Removal:** today's add-only merge leaves a removed capability's extensions and settings behind (see the Phase 1 Dev environment table). Capability conditionals should remove them instead. Covered in Trace C.
- **Repeated information:** Ubuntu focal moves into the published image, so its three copies go. Whether the stub still carries the extension list is Q6.
- **Ecosystem labels:** the `/.devcontainer` entry adds another ecosystem with no Terraform label. Covered under GitHub settings.
- **`docs-astro`:** adds Node to the toolset (A7) and a Node version to the stub (B3). No `.editorconfig` section is needed: `.astro`, `.mjs` and `package.json` fall under the default `*` section (`editorconfig_config.json:2-12`). No extensions today (`repository_vscode_extensions.json:114-134`), and none planned for now (maintainer's decision).

**Repository hygiene**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.gitignore`, template sections | Template | `copier copy` |
| `.gitignore`, maintainer additions (`image/proto/node_modules/`, below the marker, 3.3) | Maintainer | Hand edit |
| `.markdownlint.json` | Template | `copier copy`, reset on every `copier update` (3.4) |

References: `.gitignore` is class 5 (UDF `:99`). Its sections follow the capabilities: `target/` and `**/*.rs.bk` from `rust-app`, `.docker/` from `container` (UDF `:134`, `:244`). `.markdownlint.json` is class 4, owned whole and reset by a migration (3.4), rather than class 3 (UDF `:96`).

- **Paket entries:** an unconditional template section, since every repo has the build. `paket.lock` and `paket-files/` go (Paket `:170`). The new `packages.lock.json` has to be committed, because Dependabot bumps it with the manifest (Paket `:97`); today's comment says the lock is ignored on purpose (`.gitignore:4`). `packages/` stays only if restore stays repo-local (Paket D4, `:179`). The restore project's `obj/` and `bin/` need ignoring (Paket V8, `:195`).
- **V6 holds (E9), but isn't used here:** an `extends` stub would need a shared file at a fixed path, and a repo's own file would still win (E28). The template owns the whole file instead (3.4).
- **Manual sections:** `.gitignore` keeps a marker comment, which nothing parses, and local lines go below it (3.3).
- **Removal:** dropping a capability should drop its ignore lines. Covered in Trace C.
- **`docs-astro`:** adds a template section: `node_modules/`, plus `dist/` and `.astro/` under the docs path, which Copier needs to render them (A1). Whether to anchor `node_modules/` to the docs path is Q7. `package-lock.json` is committed, so it stays unignored (3.8). `.markdownlint.json` is one config for every type today (`Compare-BrownserveRepository.ps1:803`), and Astro doesn't change it.

**Docs**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `README.md` | GitHub (auto-init), then Maintainer | Repo creation; Hand edit |
| `CHANGELOG.md`, header and placeholder ⚠ A10 | Template | `copier copy` (scaffold) |
| `CHANGELOG.md`, entries | Release history | Staged release |
| `LICENSE` | GitHub's licence list, chosen in Terraform | Repo creation |
| `CLAUDE.md` | Maintainer | Hand edit |
| `CONTRIBUTING.md`, baseline and capability sections | Template | `copier copy` |
| `CONTRIBUTING.md`, repo additions (below the marker, 3.3) | Maintainer | Hand edit |
| `pull_request_template.md`, baseline and capability items | Template | `copier copy` |
| `pull_request_template.md`, repo additions (below the marker, 3.3) | Maintainer | Hand edit |
| `docs-astro` scaffold (`package.json`, `astro.config.mjs`, `index.astro`) ⚠ T5 | Template | `copier copy` (scaffold) |
| `docs-astro` site content after scaffolding | Maintainer | Hand edit |

References: CONTRIBUTING and the PR template are class 2 (org `.github` defaults) or class 4 (UDF `:95`, D3 `:282`). `CHANGELOG.md` is a class 6 scaffold through `_skip_if_exists` (UDF `:81`, `:102`, `:138`). Capability sections follow the capabilities (UDF `:134`, `:244`); a repo addition is carried by the merge below a marker comment (UDF `:245`, 3.3), or the file is ejected (UDF `:246`).

- **Per-repo variation:** CONTRIBUTING and the PR template share a baseline, and repos (even with the same capabilities) add their own items (confirmed by the maintainer). That rules out class 2: GitHub only falls back to the org copy when the repo has none (UDF `:77`), and doesn't merge the two, so one extra item would cut the repo off from baseline updates. Today nothing carries a repo addition: both files are compared whole and replaced (`Compare-BrownserveRepository.ps1:1962-1974`, `:2019-2031`), with no manual section marker.
- **`container` gap:** what a `container` section would hold is Q8.
- **Licence:** set with `license_template` on the repo's module call (maintainer's proposal). GitHub keeps the licence texts, so the template doesn't ship a `LICENSE` and `New-SPDXLicense` retires. It's create-only: changing it later neither replaces the repo nor changes `LICENSE` (E16); the copyright line uses the org's display name, `Brownserve`.
- **README scaffold:** `auto_init` (`modules/github-brownserve_repo/repository.tf:9`) already writes `README.md`, so a Copier scaffold under `_skip_if_exists` would be skipped. This differs from UDF `:81`, `:102`. Confirmed with Copier (E17).
- **Repeated information:** the Conventional Commits types are Q11. `CLAUDE.md` still restates facts the capabilities own (binary name, GHCR).
- **`docs-astro`:** adds the Astro scaffold (class 6, UDF `:102`), a CONTRIBUTING section and a PR template item, which the existing capability rows cover. Both texts name the docs path (today `pages/`, `SkillsRepo_github_contributing.md.template:14-17`, `SkillsRepo_github_pull_request_template.md.template:15`), so Copier needs it to render them (A1). The skills section lists no Node prerequisite; in `bsdev` it would sit with Rust and PowerShell (`CONTRIBUTING.md:7-8`). `index.astro` says "Documentation for our agent skills" (`skillsrepo_astro_index.astro.template:14`), which needs generic wording.
- **Site URL:** Astro sites go under `docs.brownserve.co.uk`, as MkDocs sites do today (`mkdocs.yml.template:2`) (maintainer's decision). Today's Astro scaffold uses `https://<owner lowercase>.github.io` with base `/<repo>` (`skillsrepo_astro_config.mjs.template:4-5`). The domain is the CNAME of the org Pages site (`repos.tf:111-113`), so it's stated in Terraform and in the scaffold. Project sites are served under the org's custom domain (E15). `mkdocs.yml` is class 4 (UDF `:100`), so its URL is re-rendered from the answers, but the Astro config is in the class 6 scaffold, so a rename still never reaches the base path (T5).
- **MkDocs:** being dropped, with Astro as its replacement (maintainer's decision), so the two never share `pages/` or a Pages site. This differs from IBT `:117` and GHA `:121`, which list `docs-mkdocs` as a capability.

**Install scripts**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `install.sh` ⚠ A11 | Maintainer | Hand edit |
| `install.ps1` ⚠ A11 | Maintainer | Hand edit |

References: UDF makes them class 4, or class 1 if moved into a release asset or a shared URL (UDF `:101`). The maintainer's position is that they're project-specific and not distributed at all, which differs from UDF `:101`.

Retired: `rustapp_install.sh.template`, `rustapp_install.ps1.template` and the generator's install script handling (`Compare-BrownserveRepository.ps1:2218-2280`).

- **New repos:** `bsdev` keeps its current scripts. A new `rust-app` repo starts with no installers and gets them only if the maintainer writes them.
- **Later:** if binary-producing repos become common, the installers could come back as a template scaffold or a release artefact built by `Package` (UDF `:101`, class 1). Only the artefact route clears A11, because the same task would name the assets and write the installer. A `docs-astro` site could also serve them from a fixed address under `docs.brownserve.co.uk`, which is UDF's shared URL route (`:101`). That goes against installers being per project and isn't verified.
- **Repeated information:** the installers' copy of the binary name stays, now held by the maintainer alongside the project config's (IBT `:142`).

**Generator**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.copier-answers.yml`, answers (capabilities, plus any settings the template needs) | Maintainer | `copier copy` |
| `.copier-answers.yml`, template version (`_commit`) ⚠ B1 | Template | `copier copy` |
| Project config ⚠ A1 | Maintainer | Not settled: the same file as the answers, rendered from them, or a hand edit |

Retired: `.brownserve_repository_manifest` (UDF `:103`).

- **`docs-astro`:** adds one setting, the docs path (today `pages`, `repository_paths_config.json:131-136`), needed only when `docs-astro` is declared. Whether Copier can ask it only for that capability, and whether `copier update` prompts for a new question or needs it passed in, are not verified (E5).

**GitHub settings**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Required checks ⚠ A13 | Terraform | Terraform apply |
| Issue labels | Terraform | Terraform apply |
| Branch protection, push restriction, signed commits, code owner reviews | Terraform | Terraform apply |
| CI app install and its secrets, now also needed for template sync ⚠ A12 | Terraform | Terraform apply |
| `SLACK_WEBHOOK_BUILD` | Terraform | Terraform apply |
| `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` ⚠ A12 | Terraform | Terraform apply |
| GHCR push (`packages: write` in the `release` stub) | Template | `copier copy` |
| Licence choice (`license_template`, new module variable) | Terraform | Terraform apply (create only) |
| GitHub Pages, `legacy` from `gh-pages` (`docs-astro`) ⚠ T5 | Terraform | Terraform apply |
| Pages deploy permission (`contents: write` in the `release` stub) | Template | `copier copy` |

References: Terraform stays the owner of settings, secrets and the consumer list (UDF `:186`); set-up is a Terraform change, then `copier copy` (UDF `:266`). The Terraform boundary is GHA C5 (`:161`), not yet written. Check names through a reusable workflow (GHA `:168`, V6 `:191`) and emitted check names as part of the shared workflow contract (GHA C2, `:158`). The permission ceiling lives in the stub (GHA `:86`). The App installation list doubles as the template sync's consumer list (UDF `:230`).

- **Terraform's own classification:** Terraform doesn't use project types or capabilities. It has `issue_types` (`application`, `powershell` and others, `variables.tf:117-125`; `bsdev` is `application`) and hand-kept lists that each grant something: `release_secrets_repos` (`secrets.tf:125-134`), `powershell_module_secrets_repos` (`:153-160`, in effect a `powershell-module` list), `brownserve_ci_app_repos` (`apps.tf:34-63`) and the two team lists (`teams.tf:10-18`, `:37-47`).
- **Docker Hub secrets:** move from hand-set to Terraform (maintainer's decision). `secrets.tf` has no list for them today, so a new one is needed alongside `powershell_module_secrets_repos`. `bsdev`'s are hand-set today (see the Phase 1 GitHub settings table), so they need importing when Terraform takes them over; otherwise removing `container` leaves them behind, since Terraform deletes only what it manages.
- **Labels:** the title-to-label mapping moves to the Tier 1 `action-label-pr` (GHA `:127`), released separately from Terraform's label list, so the `removed`/`removal` mismatch carries over. `nuget`, `npm` and the dev container ecosystem add cases to the Dependabot ecosystem labels question, and the template's `dependabot.yml` could set `labels:` per entry so Dependabot only applies labels Terraform defines (Q3).
- **`docs-astro` Pages:** stays on `legacy` from `gh-pages` (maintainer's decision), so the deploy pushes a branch as today (`skillsrepo_github_release.yaml.template:86-98`), rather than GHA `:132`'s `actions/deploy-pages` option. Terraform can set `gh-pages` as the source before the first deploy creates the branch (confirmed by the maintainer), so the "Terraform first" order (UDF `:266`) holds. The deploy uses only `GITHUB_TOKEN`: no new secret, and no change to the repo lists. The per-repo block sets no CNAME; the site sits under the org site's `docs.brownserve.co.uk` (`repos.tf:111-113`).
- **`docs-astro` permissions:** the push needs `contents: write` (`skillsrepo_github_release.yaml.template:67-68`), which raises the `release` stub's ceiling: `bsdev` grants only `contents: read` and `packages: write` today (`release.yaml:59-61`).
- **`docs-astro` required checks:** none added if the site build sits behind the gate job (A13, B2).
- **Unused secrets:** `bsdev` doesn't read `GH_TOKEN_*` or `GPG_KEY_AUTOMATED_BUILD`. Retiring them is out of scope here (GHA `:197`).
- **Repeated information:** the three release-participating lists become four in effect, because the App list is now also the template sync's consumer list.

**Problems**

A1 to A13, B1 to B7 and C1 to C6 are in the [Register](#register).

### Trace A: declare `rust-app` + `container`

A maintainer sets up a new repository and declares it's `rust-app` + `container`. Set-up is a Terraform change followed by `copier copy` (UDF `:266`). One line per chunk: the declaration, then each group in turn.

- **Declaration.** Reached: answers file, project config. Problems: A1. The workflow stubs' `capabilities` input (GHA `:108`) isn't a separate source: Copier renders the stubs from the answers (UDF `:89`, `:262`).
- **Build.** Reached: shared tasks and stock tests (through the task package), bootstrap, project build script, project tests, dependency manifest and lock file, `nuget.config`. Problems: A2, A3. Clears T4, and T2 for the tests (the template no longer writes the test file).
- **CI workflows.** Reached: shared workflow logic (through the stubs), stubs for `ci`, `pr-checks`, `stage-release`, `release` and template sync, and their pins. Problems: A4, A5. Narrows T1 to A4: a conflict only when the template moves its own pin, rather than every regeneration reverting it. Clears T2 for `publish_to`: the input becomes part of the template, and a hand edit in a stub is kept by the 3-way merge (UDF `:135`), so T2 is fully cleared.
- **Dependency tooling.** Reached: `dependabot.yml`, with `cargo` from `rust-app`, `docker` at the Docker context from `container`, plus `github-actions` and `nuget`, Brownserve refs grouped and excluded from cooldown. The `Cargo.toml` files, `Cargo.lock` and `image/Dockerfile` aren't reached: they stay with the maintainer. Problems: A6. Carries T3 over unchanged; the fix would now live in the task package. Completes the T4 clear with the `nuget` entry.
- **Dev environment.** Reached: `devcontainer.json` stub and its reference, `extensions.json`, `settings.json` and `.editorconfig`, with the Rust and Docker entries from the capabilities, plus a `dependabot.yml` entry at `/.devcontainer`. The toolset (today's `.devcontainer/Dockerfile`) isn't reached: its source isn't settled. Problems: A4 (widened), A7, A8. No T problems in this group.
- **Repository hygiene.** Reached: `.gitignore`, with `target/` and `**/*.rs.bk` from `rust-app`, `.docker/` from `container`, and its Paket entries replaced by the NuGet ones; `.markdownlint.json`. Problems: A8 (applies to `.gitignore`), A9. No T problems in this group.
- **Docs.** Reached: `CONTRIBUTING.md` and the PR template, with the Rust prerequisite and `cargo` items from `rust-app` and nothing from `container`; the `CHANGELOG.md` scaffold; `README.md` and `LICENSE` from repo creation. `CLAUDE.md` isn't reached: it stays with the maintainer. Problems: A8 (applies to both checklist files), A10. No T problems in this group.
- **Install scripts.** Not reached: neither capability writes them, so `install.sh` and `install.ps1` stay with the maintainer (the maintainer's decision, differing from UDF `:101`). Problems: A11. No T problems in this group.
- **GitHub settings.** Reached by Copier: only `packages: write` in the `release` stub, from `container`. Everything else is a separate Terraform change: required checks in the `<caller job> / <called job>` form, the CI app install (now also needed for template sync), the Docker Hub secrets for `container`, labels and the licence. `rust-app` needs nothing in Terraform. Problems: A12, A13. No T problems in this group.

### Trace B: add `docs-astro`

An existing `rust-app` + `container` repo adds `docs-astro`. This is hypothetical: no repo uses it (see [Extra inventory: `docs-astro`](#extra-inventory-docs-astro)). One line per chunk: the declaration, then each group in turn.

- **Declaration.** Reached: answers file, then the same readers as Trace A (project config, `Extends` list, the stubs' `capabilities` input), plus Terraform for Pages. Route: a manual `copier update`, not the template sync. Problems: B1, plus A1 and A2 again (IBT has a `docs-astro` base script, `:117`). No T problems.
- **Build.** Reached: shared tasks (the `docs-astro` base script, through the task package), the `Extends` list, the docs path in the project config. Not reached: the dependency manifest, since Astro needs no NuGet package. Problems: B2, A1 (widened), A2. T6 is carried to CI workflows.
- **CI workflows.** Reached: shared workflow logic (Node setup, site build and docs deploy, switched on by the `capabilities` input); the `ci` and `release` stubs (the `capabilities` input, and the docs path in the `ci` path filter). Problems: B3, A1 (path filter), A4. Narrows the `docs-astro` part of T1 to A4. Carries T6 over: it clears only if the deploy publishes the task package's build.
- **Dependency tooling.** Reached: `dependabot.yml`, with an `npm` entry at the docs path from `docs-astro`; `package.json` dependency versions, first from the scaffold, then Dependabot. Not reached: `package-lock.json`, whose route isn't settled. Problems: B4, B5, A1 (the `npm` entry's directory). No T problems in this group.
- **Dev environment.** Reached: the dev container toolset (Node) and the stub's reference to it. Not reached: `extensions.json`, `settings.json` and `.editorconfig`; the default `.editorconfig` section already covers Astro's files. Problems: B6, A7 (widened), B3 (widened). No T problems in this group.
- **Repository hygiene.** Reached: `.gitignore`, with a `docs-astro` section (`node_modules/`, plus `dist/` and `.astro/` under the docs path). Not reached: `.markdownlint.json`, which is the same for every type. Problems: B7, A1 (the docs path), B4 (widened). No T problems in this group.
- **Docs.** Reached: the Astro scaffold (`package.json`, `astro.config.mjs`, `index.astro`) through `copier copy` (scaffold); a `docs-astro` section in `CONTRIBUTING.md` and an item in the PR template. Not reached: `README.md`, `CHANGELOG.md`, `LICENSE` and `CLAUDE.md`. Problems: A1 (the docs path in both files), B7 (widened). Carries T5 over: the URL moves to `docs.brownserve.co.uk`, but the scaffold is still never re-rendered.
- **Install scripts.** Not reached: `docs-astro` doesn't write them today or in the proposal, so `install.sh` and `install.ps1` stay with the maintainer. Problems: none new; A11 is unchanged. No T problems in this group.
- **Generator.** Reached: `.copier-answers.yml`, with `docs-astro` in the capabilities, the docs path as a new answer and `_commit` moved to the newest template release; the project config, with the docs path. Problems: B1, A1. Clears T7: the capability is added on its own, without a type change or a generator release.
- **GitHub settings.** Reached by Copier: `contents: write` in the `release` stub, from `docs-astro`. A separate Terraform change adds the repo's `pages` block (`legacy`, `gh-pages`). No new secrets or repo lists; `npm` adds a case to the open labels question. Problems: A12 (widened). Carries T5's Terraform half over: the `pages` block is added by hand, and its base path is the repo name in Terraform (`repos.tf:202`), which nothing checks against the scaffold.

### Trace C: remove `container`

The repo from the end of Trace B (`rust-app` + `container` + `docs-astro`) removes `container`, leaving `rust-app` + `docs-astro`. Each line also records what happens to local customisations (see Method). One line per chunk: the declaration, then each group in turn.

- **Declaration.** Reached: answers file, with `container` taken out of the capabilities, then the same readers as Trace A (project config, `Extends` list, the stubs' `capabilities` input), plus Terraform for the Docker Hub secrets. Route: a manual `copier update`, the same as adding. Its settings (Docker context, image name) lose their question; whether `copier update` drops them from the answers file or keeps them is not verified. If the project config or the `Extends` list is written by hand, the maintainer has to take out `container`, its settings and the GHCR and DockerHub publish targets, and nothing flags anything left behind. Problems: B1 (widened), A1, A2, A5. No T problems.
- **Build.** Reached: the `Extends` list, which drops `container` so its base script (Docker build, GHCR and DockerHub pushes, IBT `:115`) stops loading; the project config, which loses the Docker context, image name and publish targets. Not reached: the bootstrap, if secrets and publish targets come from environment variables (IBT `:170`) rather than today's `build.ps1` parameters; the dependency manifest, since `container` brings no NuGet package; the task package, which still ships the `container` base script; the stock and project tests, which only test the binary (`Basic.Binary.Tests.ps1:38-47`). Local customisations: a project-only task hooked onto a `container` task stops the build loading with "Missing task" (`Invoke-Build.ps1:489`), so it's caught at once; `bsdev` has none. Problems: C1, A2, A1. No T problems in this group.
- **CI workflows.** Reached: the `ci` and `release` stubs' `capabilities` input, which drops `container` so the shared workflows skip the smoke test and the GHCR and DockerHub pushes; the `ci` stub's path filter, which loses the Docker context (today `image/`, `builds.yaml:35`); the `release` stub, which loses `packages: write` (`release.yaml:61`), the GHCR and DockerHub `publish_to` options and, if secrets are passed explicitly rather than inherited (GHA `:87`), the DockerHub lines. Not reached: the shared workflow logic, which keeps the `container` jobs for other repos; the `stage-release` and template sync stubs; the pins, unless the template has moved its own (A4, since the update also moves to the newest release, B1). Required checks don't change if the smoke test sits behind the gate job (A13). Local customisations: a hand edit to the `publish_to` default sits on the line the template rewrites, so `copier update` commits a conflict (UDF `:147`); a repo's own path next to the Docker context in the filter can conflict the same way (A8 shape); `bsdev` has neither once adopted. Problems: C2, A5, A1, A4. No T problems in this group.
- **Dependency tooling.** Reached: `dependabot.yml`, which loses the `docker` entry at the Docker context (today `/image`, `dependabot.yml:18-23`) through a capability conditional (UDF `:134`, `:243`). Not reached: `image/Dockerfile` and the rest of `image/`, which are the maintainer's rather than the template's, so Copier's removal of excluded files (UDF `:136`) doesn't touch them; they stay with no Dependabot entry, CI build or build task, and removing them is the maintainer's job (maintainer's decision). The `Cargo.toml` files, `Cargo.lock` and `package.json` belong to the other capabilities. Local customisations: an `ignore` rule or other edit inside the `docker` entry sits in the block the template deletes, so `copier update` commits a conflict (UDF `:147`); `bsdev`'s entry matches the generated one, so it has none. Problems: C3. No T problems in this group.
- **Dev environment.** Reached: `extensions.json`, which loses `vscode-docker` (`:9`), and `devcontainer.json`'s copy if the stub still carries the list (`:18`); `.editorconfig`, which loses the Dockerfile and shell section (`:39-44`) while `scripts/install.sh` stays; the dev container toolset and the stub's reference, which drop Docker tooling and can conflict with Dependabot on either route (B6, C5). Not reached: `settings.json`, which has nothing specific to `container`; the Dependabot entry at `/.devcontainer`, which stays for the other capabilities. Local customisations: an extension appended after `vscode-docker` changes the line the template deletes, so `copier update` commits a conflict (UDF `:147`); a local rule inside the Dockerfile and shell section conflicts the same way (C3); `bsdev` has neither. Problems: C4, C5, A7, C3. No T problems in this group.
- **Repository hygiene.** Reached: `.gitignore`, which loses the `container` section (`.docker/` and its comment, `.gitignore:27-28`); nothing in `bsdev`'s build writes `.docker/`, so nothing becomes untracked. Not reached: `.markdownlint.json`, which is the same for every type; the maintainer's `image/proto/node_modules/` (`:31`), which goes stale once `image/` is deleted (maintainer's job). Local customisations: without the manual marker, the maintainer's line sits straight after the last template section; if that's `container`'s, the deleted block is next to the repo's line and `copier update` commits a conflict (UDF `:147`, C3), and if it's `docs-astro`'s, the removal is clean. Problems: C3 (widened), B7 (widened). No T problems in this group.
- **Docs.** Not reached: `CONTRIBUTING.md` and the PR template, which have no `container` section today and none proposed; if one is written, a capability conditional removes it, and a repo item inside or next to it conflicts (C3). `README.md` and `CLAUDE.md`, which describe the image and GHCR (`README.md:45-59`, `CLAUDE.md:46`, `:118-119`), stay with the maintainer, so updating them is the maintainer's job (maintainer's decision), as with `image/`. `CHANGELOG.md`'s `container` entries (`:28-37`) are release history and stay; `LICENSE` isn't touched. Local customisations: none reachable today; text about the image in `README.md` and `CLAUDE.md` goes stale and nothing flags it. Problems: C3 (only if a `container` section is written). No T problems in this group.
- **Install scripts.** Not reached: `install.sh` and `install.ps1` mention nothing from `container` and fetch the GitHub release assets `rust-app` produces (`install.sh:42`, `install.ps1:26`), which removing GHCR and DockerHub from the publish targets doesn't change; they stay with the maintainer. Their only link to `container` is the `.editorconfig` shell rule, which goes (C4). Local customisations: none affected, since Copier never touches the installers. Problems: C4; A11 is unchanged. No T problems in this group.
- **Generator.** Reached: `.copier-answers.yml`, with `container` taken out of the capabilities and `_commit` moved to the newest template release; whether `container`'s settings (Docker context, image name) are dropped or kept is not verified (see Declaration), and if they're kept, re-adding `container` later could reuse a stale Docker context without asking (not verified); the project config, which loses those settings and the GHCR and DockerHub publish targets. Today the same change means switching `bsdev` to `RustApp` with `-Force` (`Compare-BrownserveRepository.ps1:236-239`), which would also drop `docs-astro`, since no type has both Rust and Astro. Local customisations: none; Copier writes the answers file, and a hand-written project config is covered under Declaration. Problems: B1, A1. T7 stays cleared: removing a capability is one answer change, like adding one.
- **GitHub settings.** Reached by Copier: only `packages: write` in the `release` stub, which goes with `container` (C2). Everything else is a separate Terraform change: the repo comes out of the Docker Hub secret list, so the next apply deletes `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`. Set-up runs Terraform first (UDF `:266`), but removal has to run Copier first: if the secrets go while the stub still publishes to DockerHub, a release in between fails at `CheckPublishingParameters` (IBT `:37`). Not reached: required checks, if the smoke test sits behind the gate job (A13); the CI app, Slack secret, branch protection, Pages and labels, though the `docker` entry drops out of the open ecosystem labels question. Outside the repo: images already pushed to GHCR and Docker Hub stay, and cleaning them up is the maintainer's job (maintainer's decision); Terraform manages neither. Local customisations: none once the Docker Hub secrets are in Terraform (see the Proposed map's Docker Hub secrets note). Problems: C6, A12, C2, A13. No T problems in this group.

## Phase 3: Decisions

3.1 is an exploration session. It works through the E entries in the [Register](#register), using a throwaway Copier template in a scratch directory for the Local ones and the `copier-test` repo for anything that needs GitHub. Each finding is recorded against its E entry, and any map row or problem it changes is updated.

Decisions then run from 3.2 to 3.22 in the order of the Register's Step column.

### 3.2 A4: who owns version lines in rendered files

**Question.** Where does a version line in a rendered file come from, and who moves it after `copier copy`?

**Lines in scope for `bsdev`.** The five stub pins (`ci`, `pr-checks`, `stage-release`, `release`, template sync) and the dev container reference: one image tag, or one Feature line each for PowerShell, Rust and Docker, plus Node with `docs-astro`.

**Today.** The generator writes the pins, Dependabot bumps them, and a regeneration reverts the bumps (T1). Nothing bumps the dev container (see the Phase 1 Dev environment table).

**Readers.** GitHub (workflow call) and VS Code (dev container build).

**Options.**

| Option | What it does | Result |
| --- | --- | --- |
| A | The template's pin is fixed; Dependabot owns it after copy | New repos start stale. B6 and C5 stay. The template can't add a stub input without knowing every repo's pin is new enough (X3) |
| B | The template moves its pin each release; Dependabot bumps too | Conflicts once Dependabot has moved the line (E1) |
| C | A copy-only task writes the current pin; Dependabot owns it after | Works at set-up only (E6), so a stub or Feature added later gets no current pin. B6, C5 and X3 stay |
| D | The template owns every version line it renders, bumped by the template repo's Dependabot; each repo's Dependabot leaves them alone | Clears A4, B6, C5 and X3. Adds one hop, means more template releases, and a repo can't take a pin without the whole release |
| E | Floating `@v1` tags | Reopens GHA D2. Not pursued |

For `bsdev` under D, the template writes every one of these lines. Declaring renders the current pins. Adding `docs-astro` brings the Node Feature at the template's version. Removing `container` deletes the Docker Feature line. None of these conflict. Under A and C, adding and removing conflict once Dependabot has moved the line (B6, C5).

D can get its versions two ways:

- **D1.** The template repo's Dependabot bumps the template files directly. This needs constrained templates (E20) and doesn't work for `devcontainer.json`, where `#%` isn't a comment.
- **D2.** A pins file in the template repo, which Dependabot bumps natively and the templates read with `include` (E20). Template files stay as normal Copier.

**Decision.** D2. The template owns every version reference in a file it renders. A repo's Dependabot owns versions only in files the template doesn't render, and `exclude-paths` keeps it off the stubs (E21). Confidence: medium-high. Not yet verified: Feature pins end to end (E22), and whether security updates honour `exclude-paths` (E21).

**Knock-on.**

- UDF:
  - `:262` flips: the template owns the pin too.
  - "The template never holds versions" (`:254-256`) now covers manifests only.
  - Variant G (`:194-211`) loses its trigger, so the template sync is dispatch plus schedule (`:230`, `:235`), and E18 and V9 are moot.
- GHA `:112`, `:139`:
  - Brownserve refs' grouping and cooldown exclusion move to the template repo's `dependabot.yml`.
  - A Tier 2 fix takes one more hop: shared workflow release, pins bump, template release, sync PR.
- Template CI could render each capability mix and check each stub against the workflow its pin names (X3). The design is left for later.
- A7: image tags have no Dependabot route (E22).
- A13 and B3: shared workflow changes now arrive in a template sync PR, not a Dependabot PR, and B3's two hops become three.

### 3.3 A8: template and repo lines in the same file

**Question.** How do a repo's own lines in a file the template renders survive template releases and capability changes, and what happens when the template later adopts one? Covers B7 (adding) and C3 (removing), merged into A8.

**Files in scope for `bsdev`.**

| File | Template part | Repo part today |
| --- | --- | --- |
| `.gitignore` | Capability sections | `image/proto/node_modules/` (`:31`) |
| `.editorconfig` | Capability sections | None (manual section empty, `:46`) |
| `extensions.json`, `settings.json` | Capability entries, settings | None; repo words move to `cspell.json` (E9) |
| `CONTRIBUTING.md`, PR template | Baseline and capability items | None; other repos add items |
| `dependabot.yml` | Ecosystem entries, `exclude-paths` | None; repos may add an entry, an `ignore` rule or a group |

Out of scope: the template's cSpell words (E9), `.markdownlint.json` (A9), version lines (3.2).

**Today.** `.gitignore` and `.editorconfig` keep a manual section after a marker the generator parses, and everything above it is regenerated; a `.gitignore` without the marker stops generation. The VS Code files are merged add-only, and CONTRIBUTING and the PR template are replaced whole (see the Phase 1 Dev environment, Repository hygiene and Docs tables).

**How Copier merges.** `copier update` isn't a line-level 3-way merge. It diffs the old render against the repo, replays that diff onto the new render with `git apply`, which finds each hunk by three lines of context at any offset, and falls back to `git merge-file` only for hunks that don't apply (E24). Line numbers don't matter, so a template that grows doesn't move a repo edit. A hunk whose context also appears elsewhere can apply in the wrong place with no conflict (X4).

**Options.**

| Option | What it does | Result |
| --- | --- | --- |
| A | Accept conflicts; the sync PR shows them | Conflicts on any template change next to a repo line (E2). Needs X1's check |
| B | A fixed marker comment the template never changes, with repo additions below it | Clean on releases, adding and removing capabilities (E23). Nothing parses it, so a missing marker falls back to A |
| C | The template inserts in sorted order | Fewer conflicts, not none. Wrong where order matters |
| D | Repo additions as answers, rendered by the template | Each change needs `copier update --data`; a hand-edited answers file doesn't reach the file (E23). Editor writes bypass it |
| E | Nested `.gitignore` or `.editorconfig` | Path-scoped rules only |
| F | Eject (UDF `:246`) | Loses template updates for that file |

**Edits inside template sections.** Kept while the template leaves the section alone, and a visible conflict when it changes it (E24). In `bsdev`'s `.editorconfig`, a repo `indent_size = 2` in the PowerShell section survived a release that grew the file and changed TOML, and the removal of either capability; a release adding a PowerShell property conflicted. The exception is X4.

**Promotion.** When the template adopts a line a repo already has, the merge keeps both copies with no conflict (X5, E25). That's harmless in `.gitignore` and `extensions.json`, visible in Markdown, and an editor warning in `settings.json`. In `.editorconfig` and `settings.json` the repo's copy wins, so a different value hides the new default. GitHub rejects a duplicate `dependabot.yml` entry (E26). A version-gated migration removed the exact copy in every file; a copy with a different value needs a person.

**Resolving conflicts.** Copier has no ours/theirs option; `--conflict` only picks inline markers or `.rej` files. It does record the conflict in git's index, so straight after `copier update` the merge editor and `git mergetool` work. The sync commits the markers, which clears that, and GitHub's UI has nothing for markers inside a committed file. VS Code's merge-conflict buttons read the markers from the text and run in github.dev too, so on the sync PR's branch each conflict gets Accept Current (the repo) or Accept Incoming (the template) (E27). Considered and not needed: PR comment commands that re-run the update and resolve a file one way, and review suggestions per conflict.

**Decision (provisional).** B, with:

- One marker per file, at the end of the template's lines (`#`, `//` or `<!-- -->`); in `dependabot.yml`, at the end of `updates:`. A marker never changes, is unique in its file and ends with a newline.
- Repo edits inside template sections allowed. A conflict is resolved on the sync PR's branch with VS Code's Accept buttons: in github.dev (`.` on the PR) for simple cases, locally for anything harder (E27).
- The template sync passes `--context-lines 5` (X4) and fails on conflict markers (X1).
- A release that promotes a repo line ships a migration removing the exact copy, and CI flags any duplicate the migration can't remove (X5).
- In `dependabot.yml`, a repo adds whole entries below the marker, never a second entry for an ecosystem and directory the template covers (E26). Per-repo ignores use `@dependabot ignore` where they fit, otherwise an edit inside the template's entry (A).
- In the JSON files the template's last entry carries a trailing comma, which VS Code accepts (E25). The first line added through the editor lands above the marker and is moved by hand (E23).

Confidence: medium. To be probed further by the maintainer. Not settled:

- CONTRIBUTING and the PR template: one marker, or one per section repos extend. Depends on whether repos add items to existing sections or whole sections.
- Per-entry markers in `dependabot.yml`, if repo edits inside template entries turn out to be common (X4).
- How GitHub treats duplicate keys in one Dependabot entry, and whether a name-only `ignore` blocks security PRs (E26).
- What a migration failing partway leaves behind (E25).
- The resolution path in github.dev (E27).

**Knock-on.**

- UDF:
  - R5 (`:135`) and "Let the 3-way merge carry it" (`:245`) describe a 3-way merge; it's a diff replay with a fallback (E24). A local addition is still carried, anchored by a marker.
  - `--context-lines` is CLI only, so the sync (`:141`) sets it.
- Proposed map: `.gitignore` and `.editorconfig` keep a marker comment rather than losing it, and the Markdown and JSON files gain one.
- B7's objection to a fixed last line ("a manual marker under another name") no longer holds: nothing parses the marker, so a missing one falls back to A rather than stopping generation.
- B1: adding and removing a capability merged cleanly with markers (E23).
- Copier itself stays provisional (Q12).

### 3.4 A9: files kept identical across repos

**Question.** How does a file the template owns whole stay the same in every repo, now that Copier merges rather than overwrites?

**Files in scope for `bsdev`.** `.markdownlint.json`. Files with a marker keep repo edits by design (3.3).

**Today.** The generator overwrites `.markdownlint.json` whole (`Compare-BrownserveRepository.ps1:1704-1748`). A temporary override, such as one made while debugging, is easily forgotten; the next regeneration puts the gold standard back, which is soon enough (maintainer).

**Readers.** markdownlint in VS Code and in CI.

**Options.**

| Option | What it does | Result |
| --- | --- | --- |
| A | Class 4, merged by Copier | A local edit stays until a release changes the lines next to it, then conflicts |
| B | Class 3: a stub `extends` a file from a package | Under NuGet the path carries the version (Paket `:107`), so each bump breaks it unless something copies the file to a fixed path. The editor crashes until restore runs (E9). Rules in the stub win |
| C | No repo file: CI and the editor read a shared copy | A repo `.markdownlint.json` still wins over both (E28) |
| D | Class 4, plus a migration that rewrites the file from the template on every update | Today's behaviour: reset at each sync PR (E28) |

Copier has no setting that replaces a file whole on update (E28).

**Decision.** D. The template owns the whole file, and a `_migrations` entry with no `version` renders it and writes it after the merge on every `copier update`. A temporary override lasts until the next sync PR, whose diff shows the revert. Lasting divergence is an eject (UDF `:246`). Confidence: high. Not yet run on Windows or in the sync workflow (E28).

```yaml
_migrations:
  - command:
      - "{{ _copier_python }}"
      - -c
      - "import sys; open(sys.argv[1], 'w', newline='').write(sys.argv[2])"
      - .markdownlint.json
      - "{% include '.markdownlint.json.jinja' %}"
```

**Knock-on.**

- UDF:
  - "Overwrite is fine" (`:79`) holds for a file with this migration; other class 4 files merge.
  - `.markdownlint.json` is class 4, not 3 (`:96`).
- Q9 is answered for markdownlint. The shared cSpell list still needs a home.
- Each reset file needs its own migration entry. A file with a marker never gets one, or the repo's lines below it are lost.
- After a conflict the file is still `UU` in git but has no markers, so X1's check passes.

### 3.5 C4: a section that covers files outliving its capability

**Question.** Which capability, if any, owns an `.editorconfig` section whose patterns match files the capability doesn't bring?

**Files in scope for `bsdev`.** `container`'s section `[{Dockerfile,*.Dockerfile,Dockerfile_*,*.sh}]` (`.editorconfig:40`) matches four tracked files. Only `image/Dockerfile` and `image/bsdev-entrypoint.sh` come and go with `container`. `scripts/install.sh` is `rust-app`'s installer, kept by the maintainer (Trace A), and `.devcontainer/Dockerfile` is the dev container toolset (A7).

**Today.**

- A `RustApp` repo already ends where C4 does: it ships `install.sh` (`rustapp_install.sh.template`, 4-space indent) with no `*.sh` rule (`editorconfig_config.json:28-64`), so the script falls back to the default 2 spaces.
- `SkillsRepo` has its own `*.sh` rule (`:129-140`), so the shell rule follows shell scripts, not `container`.
- Every section in `editorconfig_config.json` agrees across types: `*.ps1` is 4 everywhere, and both `*.sh` rules are 4.

**Readers.** Editors through EditorConfig. A section that matches no file does nothing.

**Options.**

| Option | What it does | Result for `bsdev` |
| --- | --- | --- |
| A | Sections stay with their capability; the maintainer adds `*.sh` below the marker | Removing `container` drops the rule for `install.sh` and `.devcontainer/Dockerfile` with no warning. A later template adoption is a promotion (M6) |
| B | Split by file owner: Dockerfile patterns with `container`, `*.sh` in the baseline | `install.sh` keeps its rule. `.devcontainer/Dockerfile` still loses its rule unless A7 removes the file |
| C | The sync renders sections from the files in the repo | A new file type gets no rule until the next sync, and the same answers render differently. Not pursued |
| D | One `.editorconfig` for every repo: the union of every capability's sections, in the baseline, with the repo part below the marker (3.3) | Declaring, adding `docs-astro` and removing `container` leave `.editorconfig` unchanged |

**Decision.** D. The template's part of `.editorconfig` is the same in every repo and doesn't follow the capabilities. All repos stay consistent, nothing needs maintaining per capability, and a repo that gains a new file type, such as its first shell script, is already covered. D can't give two capabilities different values for the same extension, but a repo combining both couldn't either, and today's union has no clash. Confidence: medium-high.

If capability-scoped sections are wanted later, a Brownserve sync tool could build each repo's file from per-capability defaults. That isn't a requirement now.

**Knock-on.**

- C4 cleared. B7, C3 and X4 no longer arise in `.editorconfig` from a capability change, only from a template release.
- 3.3's in-scope table: `.editorconfig`'s template part is baseline sections, not capability sections.
- Proposed map: the `.editorconfig` row and its note no longer follow the capabilities. UDF `:134` and `:244` no longer apply to `.editorconfig`.
- Traces: A reaches `.editorconfig` only as a baseline file, and C no longer reaches it (`:776`, `:779`). To be confirmed in F.
- For F: check the same rule against other capability-scoped content. Content stays with a capability only if every file it covers comes and goes with it. `vscode-docker` is a likely case, since `.devcontainer/Dockerfile` uses it too.

### 3.6 A7: where the dev container's tools come from

**Question.** What provides the dev container's toolset, and who owns its versions?

**Lines in scope for `bsdev`.** `.devcontainer/Dockerfile`, and the toolset reference in `devcontainer.json`: PowerShell (every repo), Rust (`rust-app`), Docker tooling (`container`), plus Node with `docs-astro`.

**Today.**

- The generator writes one Dockerfile per project type (`devcontainer_config.json`). `bsdev` gets `RustApp`'s, so it has no Docker tooling (`:14-17`).
- Every type builds on `mcr.microsoft.com/vscode/devcontainers/base:0-focal` (`Dockerfile_*:5-6`), Ubuntu 20.04.
- `PowerShellModule` also installs .NET SDK 5.0 and Mono (`Dockerfile_PowerShellModule:29`, `:33`).
- Nothing bumps any of it.

**Readers.** VS Code Dev Containers and Codespaces, used by external contributors. Maintainers work in `bsdev`'s own image (maintainer), so the dev container only needs enough to build and test the repo.

**Options.**

| Option | What it does | Result for `bsdev` |
| --- | --- | --- |
| A | One heavy Brownserve image for every repo | One tag, nothing to change on add or remove. Ruled out: an earlier all-in-one image was big enough that a few running copies used up a contributor's free disk space (maintainer) |
| B | A Brownserve image per capability combination | The image count grows with every mix, a capability change swaps the tag, and nothing bumps image tags (E22) |
| C | Brownserve Features on a stock base image | As D, but Brownserve builds, publishes and maintains Features upstream already has |
| D | Upstream Features on a stock base image | One Feature line per capability (E14). Adding `docs-astro` adds the Node line, removing `container` removes the Docker line. Dependabot `devcontainers` bumps the versions in the template repo (E22) |

B6 and C5 don't arise under C or D: after 3.2 the template owns these lines and the repo's Dependabot is excluded from them.

**Decision.** D. Each repo's dev container is a stock Ubuntu base image plus the upstream Features for its capabilities. The template owns the Feature list, the pins file owns the versions, and `.devcontainer/Dockerfile` goes from every repo. Confidence: medium-high. Not yet verified: Feature pins end to end (E22), and the Features installing together on one base (E29).

Illustration for `bsdev` (tags and versions are placeholders):

```jsonc
{
  "name": "bsdev",
  "image": "mcr.microsoft.com/devcontainers/base:2-ubuntu-24.04",
  "features": {
    "ghcr.io/devcontainers/features/powershell:1.5.0": {},
    "ghcr.io/devcontainers/features/dotnet:2.2.0": {},
    "ghcr.io/devcontainers/features/rust:1.3.0": {},
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1.6.0": {}
  },
  "remoteUser": "vscode"
}
```

PowerShell and .NET are baseline, Rust comes from `rust-app` and Docker from `container`. Adding `docs-astro` adds a `node` line with its version option; removing `container` deletes the Docker line. A PowerShell module repo gets the first two Features only.

**Knock-on.**

- A7 cleared. UDF D4 (`:285`) answered: no Brownserve images or Features.
- New gap: the base image tag sits in `image:`, which nothing bumps (E22). Likely answer: a tag naming only the major version and OS, so rebuilds arrive without a pin change and an OS upgrade is a template change. Checked under E29, with the .NET Feature, which E14 didn't cover.
- Baseline Features are what the build needs: PowerShell, plus .NET while builds restore through Paket.
- `container`'s Docker Feature: docker-outside-of-docker or docker-in-docker, left to implementation.
- B3 (3.7): the dev container's Node version is the Node Feature's option, rendered from the pins file.
- Proposed map: the toolset row is settled and the reference row narrows to Feature versions.
- 3.5's note for F: with `.devcontainer/Dockerfile` gone, `vscode-docker` in `bsdev` covers only `image/Dockerfile`, so it comes and goes with `container`.
- Traces: A, B and C reach the toolset as Feature lines, not a Dockerfile (`:748`, `:762`, `:777`). To be confirmed in F.

### 3.7 B3: who owns the Node version

**Question.** Where does `docs-astro`'s Node version come from, in CI and in the dev container, and who moves it?

**Lines in scope for `bsdev` (after adding `docs-astro`).**

- `package.json` `engines.node`: `>=22.12.0` in the scaffold (`skillsrepo_astro_package.json.template:16`).
- The shared workflow's `setup-node`, for the PR build and the docs deploy. Today `'22'` in both templates (`skillsrepo_github_builds.yaml.template:50`, `skillsrepo_github_release.yaml.template:79`).
- The dev container's Node Feature `version` option (3.6).

**Today.** The generator writes all three, and they agree only because the templates are edited together. `package.json` is written only if missing, so a later repo edit never reaches the workflows.

**What forces a change.** A Dependabot `npm` PR for an Astro major that needs a newer Node.

**Options for CI.**

| Option | What it does | Result for the Astro bump |
| --- | --- | --- |
| A | The shared workflow hard-codes it (today's shape) | The PR fails until a shared workflow release, pins bump, template release and sync PR land (three hops after 3.2). Every `docs-astro` repo moves together |
| B | The template owns it: pins file, passed as a stub input | One hop fewer than A, still template-wide. A repo can't move ahead |
| C | The repo owns it: `setup-node` reads `node-version-file` from the docs path's `package.json` (E13) | Fixed in the same PR by raising `engines.node`. One hop, one repo |
| D | No `setup-node`; the runner's Node | Moves with the runner image and can differ per OS. Not pursued |

Under C, a range in `engines.node` floats with the runner (E13), so the scaffold should name a major: `^22.12.0` rather than `>=22.12.0`.

**Options for the dev container.** A Feature option is a literal and can't read a file.

| Option | What it does | Result |
| --- | --- | --- |
| i | A major from the pins file (as 3.6 has it) | Template-owned. Can lag once a repo raises `engines.node`; Astro's start-up Node check should make the gap loud in the dev container (E30) |
| ii | The `lts` channel | Moves on its own each October. Against 3.2's rule in spirit |
| iii | The sync renders it from the repo's `engines.node` | One owner for both, but the sync has to read a repo-owned file (a new requirement), and it still only refreshes on a sync |

**Decision.** C for CI, i for the dev container. The repo's `package.json` owns the Node version CI uses; the scaffold names a major. The dev container's Node Feature takes a major from the pins file. iii is logged as a possible requirement for the sync mechanism rather than decided. Confidence: medium. Not yet verified: E30.

**Knock-on.**

- The shared workflow needs the docs path as an input, already needed for E13 and A1.
- 3.2's "B3's two hops become three" no longer applies to CI.
- T6: both build sites read the same file, so whichever way T6 goes it adds no owner.
- B5 (3.9, parked): the scaffold's first `engines.node` goes with where the scaffold's versions come from.
- Proposed map: the Node setup row takes its version from the repo's `package.json`, and Dependency tooling gains an `engines.node` row.

### 3.8 T3 and B4: lock files

**Question.** How does each ecosystem's lock file move, and does `docs-astro` commit one?

**Today.**

- Cargo: `Cargo.lock` is committed. `UpdateCargoVersion` runs `cargo generate-lockfile` on every staged release (`build_tasks.ps1:330`). `Build` and `CargoTest` don't pass `--locked` (`:490-507`, `:525`), so a stale lock is rewritten silently.
- npm: no lock. The base script and the deploy run `npm install` (B4).
- NuGet: the Paket proposal commits `packages.lock.json` and restores with `--locked-mode` (E7).

**Checked locally (E31).** On a copy of `bsdev` with the version bumped from 0.10.0 to 0.11.0, `cargo generate-lockfile` re-resolved all 263 packages and moved 20 third-party crates as well as the two workspace crates. `cargo update --workspace` moved only `bsdev` and `bsdev-core`. Cargo with `--locked` failed against the stale lock. `npm ci` failed with no lock, and with a lock that didn't match `package.json`.

**Options for T3.**

| Option | What it does | Result |
| --- | --- | --- |
| A | Keep `cargo generate-lockfile` | Every release moves dependencies with no Dependabot PR, against 3.2's rule. Not pursued |
| B | `cargo update --workspace` | Only the workspace's own versions move. Third-party crates move only through Dependabot |
| C | Stop committing `Cargo.lock` | Builds aren't reproducible and Dependabot has nothing to bump. Not pursued |

**Options for B4.**

| Option | What it does | Result |
| --- | --- | --- |
| A | No lock, `npm install` (today) | Every CI run resolves again, so a new Astro release reaches the site with no PR. The same shape as T3 |
| B | Commit `package-lock.json`, CI runs `npm ci` | Dependabot `npm` bumps the manifest and lock in one PR. CI fails if they drift |

**Rule, for Cargo, npm and NuGet.**

1. Every ecosystem commits a lock.
2. Local builds may update it (plain `cargo build`, `npm install`), so a maintainer's manifest change brings its lock change in the same PR.
3. CI fails rather than rewrite it: `--locked`, `npm ci`, `--locked-mode`.
4. Release tooling touches only the workspace's own version.

**Decision.** B for T3, B for B4, under the rule above. Confidence: high. Not yet verified: Dependabot `npm` updating `package-lock.json` with `package.json` (E31).

**Knock-on.**

- Task package: `UpdateCargoVersion` runs `cargo update --workspace`. `Build` and `CargoTest` pass `--locked` in CI. The `docs-astro` base script runs `npm ci` in CI and `npm install` locally. The task package has to know when it runs in CI.
- `--locked` and `npm ci` are CI-only, so a local `Cargo.toml` edit doesn't fail the next build, and local builds don't reinstall `node_modules` every run.
- First npm lock: `npm ci` fails without one, so the first `npm install` is a one-time step. Who runs it is 3.9 (parked, M11). Until then, the base script fails with a clear message telling the maintainer to run `npm install` and commit the lock.
- `.gitignore`: `package-lock.json` stays unignored.
- Proposed map: the `Cargo.lock` and `package-lock.json` rows are settled.

## Sync mechanism requirements

Copier was ruled out after 3.4 (Q12). This section separates what 3.2 to 3.4 decided from how Copier would have done it, and turns the Copier findings into requirements for the replacement. The E entries still describe Copier, so any requirement can be checked against them.

### Rules and mechanisms so far

| Decision | Rule (stands) | Copier mechanism (dropped) |
| --- | --- | --- |
| 3.2 A4 | The template owns every version line in a file it renders. The versions come from a pins file in the template repo, which Dependabot bumps natively. A repo's Dependabot owns versions only in files the template doesn't render, and `exclude-paths` keeps it off the stubs (E21) | Reading the pins file with `include` and `regex_search` (E20) |
| 3.3 A8 (provisional) | A fixed marker separates the template's lines from the repo's. Repo edits inside template sections are kept until the template changes those lines, then they conflict. A line the template adopts is removed from the repo's part | Diff replay with `git apply` (E24), `--context-lines 5`, a `git diff --check` in the sync, version-gated `_migrations` |
| 3.4 A9 | A file the template owns whole is reset on every sync. Lasting divergence is an eject | An every-update `_migrations` entry (E28) |

3.3 stays provisional. A tool we write can parse the marker, which reopens what a missing marker should do (B7).

### Requirements

| ID | Requirement | From |
| --- | --- | --- |
| M1 | Each file has an ownership mode: rendered whole and reset on every sync; a template part and a repo part split by a marker; a scaffold written once and never updated; or ejected | A8, A9, E17, E23, E28 |
| M2 | A repo edit stays where it is or becomes a conflict. It never moves without one | X4, E24 |
| M3 | An edit inside a template section is kept while the template leaves those lines alone, and conflicts when the template changes them | 3.3, E24 |
| M4 | A conflict is reported in the exit code, so the sync workflow can stop before opening a PR | X1, E1 |
| M5 | Conflict markers are in git's format, so VS Code's merge-conflict extension reads them, with the repo as Current and the template as Incoming. There's a way to take one side for a file or a hunk | E27 |
| M6 | When the template adopts a line from a repo, an identical copy in the repo's part is removed and a different value is flagged | X5, E25, E26 |
| M7 | Version lines are rendered from a pins file that Dependabot bumps natively. Template source never has to parse as the ecosystem's own file | 3.2, E20, E22 |
| M8 | A capability change is its own operation. It stays on the repo's current template version and runs unattended | B1, E3 |
| M9 | Re-adding a removed capability says when a dropped setting comes back with its default, instead of losing the earlier value silently | E4 |
| M10 | A template release that adds a question with no default doesn't stall unattended syncs. Either template CI requires a default, or the sync fails visibly for that repo | X2, E5 |
| M11 | Hooks know which operation is running (set-up, update, capability added, capability removed) and run once in the repo, so adding a capability can install its packages and write its first lock file | A3, B4, B5, E6 |
| M12 | Output is the same on Linux, macOS and Windows, including line endings | E28 |

### Open for the parked steps

- Whether the tool's answers file is the project config, renders it, or is separate (A1), and whether Terraform reads it (A12).
- What a missing marker does: stop, as today's generator does, or fall back to a conflict, as Copier did (3.3, B7).
- Possible M13: rendering a value from a repo-owned file, e.g. the dev container's Node major from `engines.node` (3.7, option iii).

## Register

The single list of problems, open questions and things to check. The maps and traces refer to entries by ID. The prefix records where an entry came from: T from today's map, A, B and C from Traces A, B and C, Q for open questions, E for things to check, and X for problems found in Phase 3. Merged and cleared entries keep their text so the traces still read correctly.

Step is the Phase 3 step that settles the entry; F means the final pass.

### Problems

| ID | Summary | Depends on | Step | Status |
| --- | --- | --- | --- | --- |
| T1 | Action pins arrive by two routes | | | Merged into A4 |
| T2 | Hand edits inside files replaced whole | | | Cleared (Trace A) |
| T3 | `Cargo.lock` moves outside Dependabot | E7, E31 | 3.8 | Decided (3.8) |
| T4 | Paket version has no update route | | | Cleared (Trace A) |
| T5 | `docs-astro` site URL never re-rendered | E15 | 3.13 | Parked: depends on whether `astro.config.mjs` is a scaffold or rendered (M1) |
| T6 | `docs-astro` site built two ways | | 3.14 | Open |
| T7 | `docs-astro` can't be added on its own | | | Cleared (Trace B) |
| A1 | How the project config gets written | A2, A5, A12, B1 | 3.22 | Parked: sync mechanism |
| A2 | Who writes the `Extends` list | E8 | 3.18 | Open |
| A3 | Packages into the dependency manifest at set-up | T3, E6 | 3.9 | Parked: M11 |
| A4 | Template and Dependabot write the same line | E1, E12, E19 to E22 | 3.2 | Decided (3.2) |
| A5 | Publish targets have two homes | C2 | 3.17 | Open |
| A6 | Nothing creates or checks maintainer-written files | | 3.10 | Open |
| A7 | Dev container toolset has no source | A4, E14, E22 | 3.6 | Decided (3.6) |
| A8 | Template and repo lines next to each other conflict | E2, E9, E23 to E27 | 3.3 | Provisional (3.3) |
| A9 | Nothing keeps a file identical across repos | A8, E9, E28 | 3.4 | Decided (3.4) |
| A10 | Changelog scaffold not tied to its parser | | 3.12 | Open |
| A11 | Installers not tied to the release | A6 | 3.11 | Open |
| A12 | Terraform keeps its own record | A13, T5 | 3.19 | Parked: depends on A1 |
| A13 | Check name built from three sources | E10 | 3.15 | Open |
| B1 | Capability change has no route of its own | A4, A8, E3, E4, E5 | 3.21 | Parked: M8, M9 |
| B2 | Site build entry point | | | Deferred: build restructure |
| B3 | Node version has two owners | A7, E13 | 3.7 | Decided (3.7) |
| B4 | Whether `docs-astro` commits a lock file | E31 | 3.8 | Decided (3.8) |
| B5 | Template holds the Astro version | | 3.9 | Parked: paired with A3 |
| B6 | Image route: adding conflicts with Dependabot | | | Merged into A4 |
| B7 | Adding conflicts with repo additions | | | Merged into A8 |
| C1 | Hand-written `Extends` fails silently | | | Merged into A2 |
| C2 | Permission ceiling can't follow capabilities | E11 | 3.16 | Open |
| C3 | Removal conflicts with local edits | | | Merged into A8 |
| C4 | A section covers files that outlive its capability | A8 | 3.5 | Decided (3.5) |
| C5 | Features route: removal conflicts with Dependabot | | | Merged into A4 |
| C6 | Removal order not stated | A12 | 3.20 | Open |
| X1 | Copier doesn't report a conflict | | | Copier only; requirement M4 |
| X2 | New template questions need a default | | | Copier only; requirement M10 |
| X3 | Stub shape tied to its pin | E19 | 3.2 | Decided (3.2) |
| X4 | A repo edit can move without a conflict | E24 | | Copier only; requirement M2 |
| X5 | A promoted line ends up twice | E25, E26 | | Copier only; requirement M6 |

Merged entries share a mechanism with the entry they're merged into; only the trigger differs (a template release, adding a capability, removing one). Paired entries have the same shape in another ecosystem, so one decision should cover both. B2 belongs to the wider build restructure (how the builds are split up, and what depends on what), so it isn't decided here. T6 and A13 are decided as ownership rules that hold whichever entry point the site build uses.

- **T1. Action pins arrive by two routes.** Dependabot bumps the pins in all four workflows, and a regeneration puts the template's older pins back (`builds.yaml:57`, `:82`; `Compare-BrownserveRepository.ps1:1863-1876`). The same applies to the `docs-astro` `setup-node` pins.
- **T2. Hand edits inside files the generator replaces whole.** These are the `publish_to` input in `release.yaml` (`:5-10`, `:96`) and the extra tests at `Basic.Binary.Tests.ps1:38-47`. A regeneration drops both.
- **T3. `Cargo.lock` moves outside Dependabot.** On every staged release, `UpdateCargoVersion` runs `cargo generate-lockfile` (`build_tasks.ps1:330`), which moves every dependency to its latest compatible version without a Dependabot PR. Decided in 3.8: `cargo update --workspace`, which moves only the workspace's own versions, and `--locked` in CI.
- **T4. The Paket version has no update route except a hand edit.** It's only written when the file is missing (`Compare-BrownserveRepository.ps1:1326`), and `bsdev` has no Dependabot `nuget` entry. The PowerShell module types do have one (`:426`, `:488`).
- **T5. The `docs-astro` site URL has no update route except a hand edit.** `astro.config.mjs` is only written if missing (`Compare-BrownserveRepository.ps1:2391-2394`), so a repo rename or owner change never reaches it. It also has to match the Pages setting in Terraform, and nothing checks the two agree.
- **T6. The `docs-astro` site is built two ways.** PR checks build it through `BuildDocs` (`skillsrepo_build_tasks.ps1.template:373-385`); `deploy-docs` runs its own npm steps (`skillsrepo_github_release.yaml.template:84-85`). A change to one doesn't reach the other.
- **T7. `docs-astro` can't be added on its own.** A repo has one project type (`Module/Private/Classes.ps1:564-573`), and only `SkillsRepo` turns Astro on (`Compare-BrownserveRepository.ps1:810`), with its parts written into the skills templates. Giving `bsdev` Astro means either switching it to `SkillsRepo` with `-Force` (`:236-239`), which drops the Rust and container files, or changing the `bsdev` branch of the generator (`:690-783`) and releasing it.
- **A1. How the project config gets written isn't settled.** It could be the answers file itself, rendered from it, or written by hand (UDF `:264`, `:285`). If it's written by hand, the capabilities and settings such as the Docker context would be stated in two files: Copier needs the Docker context to render `dependabot.yml` and the CI stub's path filter (UDF `:134`), and the build tasks read it from the project config (IBT `:142`). The `docs-astro` docs path has the same shape: Copier needs it to render the `npm` Dependabot entry, the CI path filter and the `.gitignore` lines, and the build tasks read it from the project config.
- **A2. Nothing settles who writes the `Extends` list.** The project build script's `Extends` list names the capabilities (IBT `:147-155`), a third place they're stated after the answers file and the project config. If the template renders it, the maintainer's project-only tasks sit in a template-owned file. If the maintainer writes it, it can drift from the answers (removing `container` wouldn't touch it). It might instead be worked out at run time from the project config (IBT V4, `:231`), which could make the build script identical everywhere and shippable in the package (IBT `:162`, D6 `:220`). Run time works (E8). With the list read from the project config and project-only tasks in their own file, the build script is the same in every repo, so A2 now depends on A1.
- **A3. Nothing settles how packages get into the dependency manifest at set-up.** The template never holds versions, so even shared packages need `dotnet add package`. UDF suggests a Copier migration or task (`:256`); only a task fits at set-up, because migrations run when an update crosses a version (UDF `:136`). A Copier task works at set-up (E6), but not for a capability added later: tasks run three times on every update and can't tell a capability was just added. Paket D7 (`:182`) is still open. For `bsdev` every package is shared by all capabilities, so a capability bringing its own package comes up in later traces.
- **A4. Nothing settles where the template's pin comes from, or whether it ever moves.** Dependabot owns the pin (UDF `:262`), but the stub is rendered from the template, so the first pin has to come from it. Copier's 3-way merge keeps Dependabot's bump only if the template leaves that line alone, or moves it to the same value; any other move conflicts (E1). If the template pins `ci` at `v1.0.0`, Dependabot bumps `bsdev` to `v1.2.0`, and the next template release moves its pin to `v1.1.0` so new repos start more current, `copier update` sees both sides change the same line and commits a conflict (UDF `:147`). The manifest versions had the same shape and were answered by the template never holding versions (UDF `:254`); the research has no equivalent for pins. The dev container stub's image or Feature reference has the same shape (see Dev environment). Decided in 3.2: the template owns the line (D2).
- **A5. Publish targets have two proposed homes.** The project config holds publish targets (IBT `:142`), and dispatch inputs live in the stub (GHA `:85`). Today's `publish_to` is a per-run choice with a default (`release.yaml:5-10`). Nothing says whether the stub still offers that choice, or how its default relates to the config's list. Both follow the capabilities (`container` brings GHCR and DockerHub), so removing `container` would need both changed.
- **A6. Nothing creates or checks the files the capabilities expect the maintainer to write.** The shared tasks assume the root `Cargo.toml` has `[workspace.package]` with a `version` (`build_tasks.ps1:316-320`, or `StageRelease` fails), the binary in `cli/Cargo.toml` is named `BinaryName` (`:567-571`, or `Package` can't find it), and a Dockerfile sits in the Docker context (`:131`, `:184`, or `BuildImage` fails). The binary name and Docker context are also in the project config (IBT `:142`), with no route between the two. A new `rust-app` repo made with `cargo new` has no `[workspace.package]`, so it builds and tests fine until its first `StageRelease`. The research's scaffold class (class 6) lists only `LICENSE`, `CHANGELOG.md`, `README.md` and the Astro scaffold (UDF `:81`, `:102`).
- **A7. The dev container toolset has no settled source.** `bsdev` needs PowerShell (every repo, because the build runs in `pwsh`), Rust (`rust-app`) and Docker tooling (`container`, missing today, see the Phase 1 Dev environment table). A dev container uses one image, so an image per capability can't be combined, and an image per combination grows with every new mix. A base image plus one Feature per capability combines, but each Feature has to be built and published. Images or Features is still open (UDF D4, `:283`), and no research doc says which repo builds and publishes them, or with what workflow. `docs-astro` adds Node, which no dev container installs today (`SkillsRepo` has none: `Compare-BrownserveRepository.ps1:784-793`, `:893`). Upstream Features exist for Node and every other capability's tooling (E14), so the Features route may need no Brownserve build. No Dependabot ecosystem bumps an image tag in `devcontainer.json`, so on the image route the template's tag has no update route (E22). Decided in 3.6: upstream Features on a stock base image, versions from the pins file.
- **A8. Additions from the template and the repo to the same list can conflict.** When both append to the end of a list in a class 5 file, their edits touch the same or adjacent lines. In JSON, appending also adds a comma to the previous last line. If the maintainer adds `"bsdev"` after `"yzhang"` in the cSpell words (`settings.json:15`), and the next template release also adds a word at the end, both sides change `"yzhang"` to `"yzhang",` and `copier update` commits a conflict. UDF's "a cSpell word the template didn't touch is kept" (`:135`) holds only when the template's change is elsewhere in the list. The same applies to `extensions.json` and `.gitignore`. Confirmed (E2). Only the appended lines conflict, and a template edit with at least one unchanged line between it and the repo's merges cleanly, so a template that inserts mid-list rather than appending avoids it, unless the repo has edited next to the same point. V6 holds (E9), so the template's cSpell words move to a read-only shared list and drop out of this. The repo's own words stay in the stub, which the template doesn't add to, and the extension inserts them alphabetically rather than appending. Provisionally decided in 3.3: a marker comment the template never changes, with repo additions below it.
- **A9. Nothing keeps a file identical across repos once Copier merges.** Today `.markdownlint.json` is overwritten whole so that no repo drifts (`Compare-BrownserveRepository.ps1:1704-1748`). Copier's 3-way merge keeps any local edit the template didn't touch (UDF `:135`). That includes class 4 files, whose "overwrite is fine" (UDF `:79`) isn't how Copier updates them. As class 3, the local half exists to hold local rules (UDF `:78`, `:245`). Either way a repo could switch a rule back on and keep it on without ejecting, though ejecting is the research's visible route for divergence (UDF `:246`). The research doesn't say whether the "no local changes" rule should survive. Decided in 3.4: it survives, reset by a migration on every update.
- **A10. Nothing ties the changelog scaffold to the parser that reads it.** Today the header and its `v0.0.0` placeholder come from `New-BrownserveChangelogHeader.ps1:7-20`, and `Read-BrownserveChangelog` detects that exact placeholder (`Read-BrownserveChangelog.ps1:203`). Both live in PSBuildTools and release together. As a scaffold, the placeholder moves into the template, while the parser stays in a Brownserve module the task package uses. If the parser's format changes, a repo set up from an older template release gets a placeholder the parser doesn't recognise, and its first staged release treats `v0.0.0` as a real release. It only matters before a repo's first release.
- **A11. Nothing ties the installers to the release they install.** Each installer hard-codes the asset name (`install.sh:42`, `install.ps1:26`), the targets (`install.sh:26`, `:32`, `install.ps1:25`) and the binary name (from the repo name). In the proposal these are decided by the task package's `Package` task (IBT `:131`), the `release` stub's targets input (GHA `:133`) and the project config (IBT `:142`). Nothing checks them today either (see the Phase 1 Install scripts table), but today the installers and the build tasks come from the same generator and change together. Proposed, they have separate owners and releases. If a task package major release changes the asset layout (a breaking change, IBT `:182`), or the stub drops `aarch64-apple-darwin`, CI stays green and the breakage only shows up when someone runs the `README.md` one-liner.
- **A12. Terraform keeps its own record of what each repo is.** A repo declares its capabilities in the Copier answers (UDF `:265`), but Terraform decides what the repo gets from `issue_types` and its hand-kept lists, and nothing links the two. Declare `container` and Terraform also has to add the repo to a new Docker Hub secret list, or the first `Release` fails at `CheckPublishingParameters` (IBT `:37`). Every repo needs to be in `brownserve_ci_app_repos`, or the template sync can't get an App token and the repo never receives template updates. Remove `container` and the secrets stay behind unless Terraform is changed too. GHA C5 (`:161`) names the boundary but doesn't say which side is the source. The maintainer plans to refactor the Terraform set-up to link labels, secrets and contributors (not yet researched). That could let the module call work out the lists from one declaration, but it would still be separate from the Copier answers unless one reads the other. Declare `docs-astro` and Terraform also needs a `pages` block for the repo; without it the deploy pushes `gh-pages` successfully and the site never goes live.
- **A13. A required check name is built from three sources.** `<caller job>` comes from the template (the stub's job name), `<called job>` from the shared workflows (GHA `:158`), and the full string is stated in Terraform's `required_status_checks` (`repos.tf:211`). Today there are two: the job name in `builds.yaml:98` and Terraform. If a shared workflow release renames its gate job, each repo's Dependabot bump PR reports the new name and never the old one, and strict protection with `enforce_admins` (`repository.tf:46`, `:59`) stops it merging. If Terraform changes first, every repo that hasn't taken the bump is blocked instead. Whether `rust-app`'s matrix and `container`'s smoke test sit behind one gate job with a fixed name (GHA `:129`) isn't settled; if the name varies by capability, Terraform has to know the capabilities too, which ties A13 to A12. Names confirmed (E10). A required check skipped by `if:` passes, so a capability's job can be required in every repo.
- **B1. Adding or removing a capability has no route of its own.** The template sync runs `copier update --defaults` (UDF `:141`), which reuses the recorded answers, so changing a capability needs a manual `copier update`. That needs Python (`:145`), `--trust` (`:149`) and a clean tree (`:150`). By default it also moves the repo to the newest template release, so the PR adding `docs-astro` can carry unrelated template changes and conflicts. `--vcs-ref=:current:` keeps the repo on its current template version, so the PR carries only the capability change (E3). A removed capability's settings are dropped from the answers, and re-adding it gives their defaults, not the earlier values (E4). The maintainer considers this a heavy-handed way to change a repo's capabilities, and wants the approach considered properly in Phase 3. Removing `container` takes the same route, with the same costs.
- **B2. Nothing says which entry point the site build hooks into.** Today it's part of `Build` (`skillsrepo_build_tasks.ps1.template:391`), and IBT's entry points table lists no docs hook (`:125-133`). `bsdev`'s PR check runs `BuildTestAndCheck` on three OSes (`builds.yaml:48-49`, `:67`). If `docs-astro` hooks `Build` the way today's task does, every PR builds the site three times, and the Linux, macOS and Windows runners all need Node. The maintainer expects the builds to be restructured as part of the main work, and the site build to be placed properly then.
- **B3. The Node version has two owners.** The shared workflow's `setup-node` sets the Node version CI installs, while the repo's `package.json` states the range Astro needs (`>=22.12.0`, `skillsrepo_astro_package.json.template:16`), scaffolded once and then the maintainer's. Today the generator writes both, plus the two workflow copies (`skillsrepo_github_builds.yaml.template:50`, `skillsrepo_github_release.yaml.template:79`), so they change together. If an Astro major needs a newer Node, Dependabot's `astro` bump PR fails until a shared workflow release raises the version and the repo takes that bump: two hops, slowed by the cooldown unless Brownserve refs are excluded (GHA `:139`). `setup-node` can read it from `package.json` (E13), leaving one owner, but a range there floats with the runner image. A dev container states the Node version a third time, in the image or as a Feature option in the stub, owned by the template. Decided in 3.7: CI reads `engines.node` from the repo's `package.json`, which names a major; the dev container takes a major from the pins file.
- **B4. Nothing settles whether `docs-astro` commits a lock file.** Today none is scaffolded, and both npm steps run `npm install` (`skillsrepo_build_tasks.ps1.template:378`, `skillsrepo_github_release.yaml.template:84`), so every CI run resolves again and a new Astro minor or patch reaches the deployed site with no Dependabot PR: the same shape as T3. The NuGet proposal commits its lock and fails the build if the manifest and lock disagree (Paket `:93`, `:97-98`); no research doc proposes the same for npm. With a lock, the base script should run `npm ci`, which fails without one, so the task package and the scaffold have to agree. The first lock would also need a Copier task running `npm install`, since a template with no versions can't ship one: the same shape as A3. As with A3, that works at set-up but not when `docs-astro` is added to an existing repo (E6). `.gitignore` has to match the answer: nothing ignores `package-lock.json` today (`gitignore_config.json:64-73`), so without a lock a local `npm install` leaves an untracked one that can be committed by accident; with a lock, it must stay unignored. Decided in 3.8: `package-lock.json` is committed, CI runs `npm ci`, and local builds run `npm install`. The first lock waits on 3.9.
- **B5. The template holds the scaffold's Astro version, and nothing updates it.** The `package.json` scaffold carries `astro ^7.3.5` (`skillsrepo_astro_package.json.template:13`), against UDF's rule that the template never contains versions (`:255`). `_skip_if_exists` keeps it from fighting Dependabot once a repo exists, but Dependabot can't bump the template's copy, so a new repo starts on whatever version was last set by hand and its first Dependabot PRs catch it up. That's the brief's GitHub Actions problem 1 in a smaller form (`2026-09-29 - Refactor.md:60`). A Copier task running `npm install astro`, as UDF suggests for NuGet (`:256`), would pick the current version instead. It does at set-up (E6), but `docs-astro` is usually added to an existing repo, where the task has no clean trigger.
- **B6. On the image route, adding a capability conflicts with Dependabot.** With one image per combination, adding `docs-astro` swaps the stub's image reference (a Rust and Docker image for a Rust, Docker and Node one) on the line Dependabot bumps. If Dependabot has bumped the tag since `copier copy`, `copier update` sees both sides change the same line and commits a conflict (UDF `:147`), on every capability change. With Features, the template adds a line and leaves the Dependabot-bumped lines alone. Not verified (UDF V1, `:293`). It weighs on the images-or-Features choice (A7, UDF D4 `:283`).
- **B7. Adding a capability can conflict with a repo's own additions.** Without the manual marker, `bsdev`'s `image/proto/node_modules/` sits straight after `.docker/` at the end of the file (`.gitignore:28-31`). If the template renders the `docs-astro` section after `container`'s, both sides add lines at the same point and `copier update` commits a conflict (UDF `:147`). Unlike A8, this happens on the change that adds the capability, not on a later template release. The PR template and CONTRIBUTING have the same shape, since repos add their own items (confirmed by the maintainer): a repo item after the `cargo` items (`pull_request_template.md:14-15`) sits where `docs-astro`'s checklist item lands, and a repo section after Building locally (`CONTRIBUTING.md:10`) sits where its CONTRIBUTING section lands. `bsdev` has neither today. Removing a capability has the same shape (C3): whichever section comes last sits next to the repo's lines, so no fixed order of sections avoids it. A fixed last line in the template, with repo additions below it, would keep the two apart, but that's a manual marker under another name, which UDF `:245` drops. Confirmed for `.gitignore` (E3).
- **C1. A capability left in a hand-written `Extends` list fails silently.** If the `Extends` list is written by hand (A2) and still names `container` after removal, nothing fails: `image/Dockerfile` stays, so every `Build` keeps building the image (IBT `:127`). A project-only task hooked onto a removed task fails loudly instead (`Invoke-Build.ps1:489`). Worked out at run time, a removed capability drops out with the config (E8).
- **C2. The stub's permission ceiling can't follow the capabilities the way the shared workflow's jobs do.** A job's `permissions` block is fixed and can't depend on an input, and GitHub fails a run when a called job asks for more than the caller grants (E11). If the shared `release` workflow's push job asks for `packages: write`, dropping it from the stub when `container` goes stops every release, even with the job switched off by `if:` (E11). Keeping `packages: write` in every stub avoids that, but grants it to repos with nothing to push. `docs-astro`'s `contents: write` has the same shape (Trace B).
- **C3. Removing a capability conflicts with local edits inside or next to its sections.** When the template deletes a capability's block and the repo has edited lines inside it, or added lines straight after it, both sides change the same or adjacent lines and `copier update` commits a conflict (UDF `:147`). If the maintainer adds an `ignore` rule to the `docker` entry in `dependabot.yml` (`:18-23`), removing `container` conflicts on that block, and the maintainer resolves it by deleting the block by hand. If `container`'s `.gitignore` section is the last template section, `bsdev`'s `image/proto/node_modules/` sits straight after `.docker/` (`.gitignore:28-31`), and the removal conflicts there too. B7 is the adding counterpart. Confirmed for `extensions.json` (E4). In JSON the line before the removed block loses its comma, so it's pulled into the conflict too.
- **C4. A capability's section can cover files that outlive the capability.** `container` brings the `.editorconfig` section for Dockerfiles and shell scripts (`:39-44`), but `*.sh` (`:40`) also matches `scripts/install.sh`, which stays with the maintainer (Trace A). Removing `container` drops the rule, so `install.sh`, indented with 4 spaces (`:12`), falls back to the default section's 2 spaces with no charset (`:12-16`), and editors indent new lines differently from the rest of the file. Nothing fails or flags it. `image/Dockerfile` and `image/bsdev-entrypoint.sh` lose their rule too, until the maintainer deletes them. Decided in 3.5: one `.editorconfig` for every repo, so no section follows a capability.
- **C5. On the Features route, removing a capability conflicts with Dependabot.** B6's escape holds only for adding. Removing `container` deletes the Docker Feature line from the dev container stub; if Dependabot has bumped that Feature's version since `copier copy`, both sides change the line and `copier update` commits a conflict (UDF `:147`). On the image route, removal swaps the reference instead, which is B6. So on either route a capability change can conflict once Dependabot has moved the line it touches. Not verified (UDF V1, `:293`). It weighs on the images-or-Features choice (A7, UDF D4 `:283`).
- **C6. Removal has to run in the opposite order to set-up, and nothing states it.** Set-up is Terraform first, then `copier copy` (UDF `:266`), so Terraform's settings are in place before the workflows use them. Removal reverses that: if Terraform deletes the Docker Hub secrets while the `release` stub still publishes to DockerHub, a release in between fails at `CheckPublishingParameters` (IBT `:37`); Copier first leaves the secrets unused until Terraform catches up. `docs-astro` has the same shape: if Terraform drops the `pages` block first, the deploy keeps pushing `gh-pages` to a repo that doesn't serve it. No research doc states the removal order, and nothing enforces either order.
- **X1. `copier update` exits 0 when it writes a conflict.** The markers are left inline and the file shows as unmerged (`UU`), but the exit code is the same as a clean update (E1). The template sync (UDF `:141`, `:235`) has to check for conflicts itself, e.g. with `git diff --check`, or it opens PRs with markers in them.
- **X2. A template release that adds a required question with no default stops the template sync.** `copier update --defaults` fails and writes nothing (E5), so every repo stays on the old release until someone passes the answer by hand. Any question added after the first release needs a default, or one worked out from other answers.
- **X3. A stub's shape is tied to the version its pin names.** GitHub checks the stub's `with:` and `secrets:` against the pinned workflow. A run fails at startup, with no jobs, if the stub passes an input or secret the workflow doesn't declare, or leaves out a required input (E19). If the pin and the rest of the stub move separately, every run in between can fail. The 3-way merge succeeds either way, so nothing flags it before the run.
- **X4. A repo edit can move to the wrong place without a conflict.** `copier update` replays the repo's diff with `git apply`, which finds each hunk by three lines of context anywhere in the file (E24). When a template change leaves another spot that looks the same, the edit lands there and the update reports success. Seen on capability removal in `dependabot.yml` and `.editorconfig`, whose entries and sections end with identical lines: a `cargo` `ignore` rule moved into the `github-actions` entry, and a `[*.rs]` line into the PowerShell section. A unique marker per entry, or `--context-lines 5`, turned each case into a conflict, but identical per-entry markers still moved with 5.
- **X5. A line the template adopts from a repo ends up twice.** The merge keeps the repo's copy below the marker and adds the template's, with no conflict (E25). The repo's copy wins in `.editorconfig` and `settings.json`, so a repo with a different value silently keeps it, and GitHub rejects a duplicate `dependabot.yml` entry (E26). A version-gated migration removes identical copies only.

### Open questions

| ID | Summary | Step |
| --- | --- | --- |
| Q1 | `removed` vs `removal` label | F |
| Q2 | Dependabot `docker` entry may do nothing | 3.1 |
| Q3 | Dependabot ecosystem labels | 3.1 |
| Q4 | Org `CODE_OF_CONDUCT.md` | 3.1 |
| Q5 | Checkout folder named after the repo | F |
| Q6 | Extension list in the dev container stub | F |
| Q7 | Anchoring `node_modules/` to the docs path | F |
| Q8 | What a `container` docs section holds | F |
| Q9 | Where the shared cSpell list lives | F |
| Q10 | Docs-only deploy trigger | 3.14 |
| Q11 | Conventional Commits types in two sources | F |
| Q12 | Copier or our own sync mechanism | Not Copier; replacement open |

- **Q1. `removed` vs `removal` label.** `label-pr.yaml:88` applies `removed`, but Terraform defines `removal` (`modules/github-brownserve_repo/issues.tf:93`). Terraform's labels are authoritative (`issues.tf:2-3`). This isn't specific to `rust-app` or `container`, but it's two sources of the same information that disagree. The changelog groups entries by these labels, so the mismatch reaches `CHANGELOG.md` too.
- **Q2. Dependabot `docker` entry may do nothing.** `image/Dockerfile:8` uses `archlinux:latest` with no version or digest. Dependabot bumps versioned tags or digests, so this entry (`dependabot.yml:18-23`) probably never opens a PR. Confirmed from Dependabot's source: `latest` isn't a version tag, so the update checker treats it as up to date and never opens a PR. With a digest pinned (`archlinux:latest@sha256:…`) it would bump the digest.
- **Q3. Dependabot ecosystem labels.** Terraform has `dependencies` and `github_actions`, but no label for `cargo` or `docker` (`issues.tf:56-97`). Because the label set is authoritative, any label Dependabot creates would be deleted on the next apply. Not verified. The proposal adds `nuget`, `npm` and the dev container ecosystem. The template's `dependabot.yml` could set `labels:` per entry so Dependabot only applies labels Terraform defines. From Dependabot's source: with no `labels:`, it creates `dependencies` and, with more than one ecosystem, the ecosystem's label: `rust`, `docker`, `.NET`, `javascript`, `github_actions`, `devcontainers_package_manager`. With `labels:` set it creates none and applies only labels that exist, so the template can set `labels:` per entry and never trigger a label Terraform deletes. Terraform's `dependencies` and `github_actions` are only in the `application` and `powershell` sets (`issues.tf:146-158`). Live on `copier-test`: with `labels:` naming labels the repo didn't have, the PR got none and none were created.
- **Q4. Org `CODE_OF_CONDUCT.md`.** `bsdev`'s PR template links to it in the `.github` repo (`repos.tf:123`). Finding: it exists (Contributor Covenant), and GitHub serves it as the default for every repo without its own (`copier-test`, `bsdev`, `PSBuildTools`). The `.github` repo holds only it and a README.
- **Q5. Does the checkout still need a folder named after the repo?** The shared workflow does the checkout, so the stubs don't need the repo name, but whether the checkout has to use a folder named after the repo is open (GHA `:19`, C4 `:160`).
- **Q6. Does the dev container stub still carry the extension list?** The list is in both `extensions.json` (`:9`) and `devcontainer.json` (`:18`) today; the research doesn't say whether the stub keeps its copy.
- **Q7. Should `node_modules/` be anchored to the docs path?** Today's entry has no leading path (`gitignore_config.json:68`), so while `docs-astro` is present the maintainer's `image/proto/node_modules/` line (`.gitignore:31`) does nothing.
- **Q8. What would a `container` section in CONTRIBUTING and the PR template hold?** Neither file mentions `container` today (see the Phase 1 Docs table), and no research doc says what a section would hold, so the gap carries over until one is written.
- **Q9. Where does the shared markdownlint file live?** If E9 holds, `.markdownlint.json` becomes an `extends` stub plus a shared file (UDF `:96`). No research doc says where the shared file lives or how it reaches the repo. E9 rules out a URL. A restored package under `packages/` works if restore stays repo-local (Paket D4, `:179`), but markdownlint crashes in the editor until the restore runs. The shared cSpell list faces the same choice, and needs `readonly` so the editor doesn't offer to add words to it. Answered for markdownlint in 3.4: no shared file, the template owns it whole. Under NuGet the restored path also carries the version (Paket `:107`), which applies to the cSpell list too.
- **Q10. How is a docs-only deploy triggered?** Today the deploy runs only after `release` (`skillsrepo_github_release.yaml.template:64`), which is `workflow_dispatch` (`:4`), so a docs-only fix waits for the next release. The maintainer wants a way to trigger the docs deploy manually on its own.
- **Q11. Conventional Commits types are stated in two separately released sources.** The table stays in the template's CONTRIBUTING, while the title-to-label mapping moves to the shared workflows (GHA D7). Today both come from the generator, so they at least change together.
- **Q12. Copier or our own sync mechanism.** Answered: not Copier. 3.3 and 3.4 found a diff replay rather than a 3-way merge (E24), edits that move without a conflict (X4), promoted lines kept twice (X5), a zero exit on conflict (X1), no way to replace a file whole on update (E28), and tasks that can't tell a capability was just added (E6). The likely replacement is a CLI that Brownserve builds and ships, not yet confirmed. Its requirements are in [Sync mechanism requirements](#sync-mechanism-requirements). Decisions that rest on Copier's behaviour cite an E entry, so they can be rechecked against it.

### To verify

Checked in 3.1; E19 to E22 in 3.2; E23 to E27 in 3.3; E28 in 3.4. E29 and E30 are not yet checked. E31 is checked in 3.8, apart from Dependabot. How: Local is a throwaway Copier template and repo in a scratch directory, Docs is vendor documentation, GitHub is the `copier-test` repo.

| ID | Summary | How | Needed by | Result |
| --- | --- | --- | --- | --- |
| E1 | Copier keeps a Dependabot bump the template didn't touch | Local | A4 | Confirmed |
| E2 | Copier merge of appends at the same point in a list | Local | A8 | Confirmed |
| E3 | `copier update` with a changed answer | Local | B1 | Confirmed |
| E4 | A removed capability's answers | Local | B1 | Dropped, not reused |
| E5 | Questions asked only for one capability | Local | B1 | Yes, with a limit (X2) |
| E6 | Copier tasks filling in versions at set-up | Local | A3 | At set-up only |
| E7 | `dotnet restore --locked-mode` | Local | T3 | Confirmed |
| E8 | `Extends` worked out at run time | Local | A2 | Confirmed |
| E9 | Shared lists through `import` and `extends` | Local | A8, A9 | Yes, from a file on disk |
| E10 | Required check names through a reusable workflow | GitHub | A13 | Confirmed |
| E11 | Permission ceiling for called jobs | GitHub | C2 | Confirmed, skipped jobs too |
| E12 | Dependabot groups and cooldown for Brownserve refs | Docs, then GitHub | A4 | Yes, with a case catch |
| E13 | `setup-node` reading `node-version-file` | Docs | B3 | Yes |
| E14 | Upstream Node dev container Feature | Docs | A7 | Yes |
| E15 | Project Pages under the org's custom domain | Docs, then GitHub | T5 | Confirmed |
| E16 | `license_template` behaviour | Docs | F | Not replaced; uses display name |
| E17 | README scaffold vs `auto_init` | Local | F | Confirmed |
| E18 | CI app key as a Dependabot secret | Docs | F | Docs: yes; run moot (3.2) |
| E19 | Stub inputs and secrets against the pinned workflow | GitHub | X3 | Confirmed |
| E20 | Dependabot on Copier template source | Docs, then GitHub | A4 | Constrained only; pins file works |
| E21 | `exclude-paths` for `github-actions` | Docs, then GitHub | A4 | Confirmed |
| E22 | Dependabot and the dev container reference | Docs, then GitHub | A4, A7 | Features only |
| E23 | A marker line under Copier's merge | Local | A8 | Confirmed |
| E24 | How `copier update` merges | Local | A8, X4 | Diff replay; can move edits |
| E25 | Promotion and duplicates | Local | A8, X5 | Both copies kept |
| E26 | Dependabot per-repo variation | Docs | A8, X5 | Duplicate entries rejected; keys open |
| E27 | Resolving a conflict in the sync PR | Local | A8 | VS Code buttons work from the text; github.dev not run |
| E28 | Replacing a file whole on update | Local | A9 | Yes, with an every-update migration |
| E29 | Dev container base image tag and baseline Features | Docs, then Local | A7 | Not checked |
| E30 | Node version checks for `docs-astro` | Docs, then Local | B3 | Not checked |
| E31 | Lock file commands for Cargo and npm | Local; Docs | T3, B4 | Confirmed, except Dependabot `npm` (not checked) |

- **E1. Copier keeps a Dependabot bump the template didn't touch.** Copier's 3-way merge should keep a line Dependabot changed when the template leaves it alone, and commit a conflict when both change it (UDF `:135`, `:147`, V1 `:293`). Finding: confirmed with Copier 9.18.2. A Dependabot bump to `@v1.2.0` survived a template release that added a line two lines above it. When the next release moved the template's pin from `v1.0.0` to `v1.1.0`, `copier update` wrote inline conflict markers on that line. Moving it to `v1.2.0`, the value Dependabot had already set, merged cleanly. Copier exits 0 either way (X1).
- **E2. Copier merge of appends at the same point in a list.** When the template and the repo both add to the end of a list, including JSON's comma on the previous last line, `copier update` is expected to conflict (A8, B7, C3). Finding: confirmed. When the repo and template both appended to the end of the cSpell words, the extensions list and a `.gitignore` section, all three conflicted. The comma both sides added to the previous last line merged; only the appended lines conflicted. Template edits with at least one unchanged line between them and the repo's edit merged cleanly: a word inserted mid-list, an extension with one line between, a line in another `.gitignore` section.
- **E3. `copier update` with a changed answer.** How Copier takes a changed answer, and whether it can stay on the current template version rather than moving to the newest (B1). Finding: `copier update --defaults --vcs-ref=:current: -d capabilities=[…]` changed the answer and left `_commit` where it was, so the diff held only the capability's changes. Without `--vcs-ref`, Copier moves to the newest tag (PEP 440 order). Adding `docs-astro` this way conflicted in `.gitignore`, where the repo's line sat straight after `.docker/` (B7).
- **E4. A removed capability's answers.** Whether `copier update` drops a removed capability's settings (Docker context, image name) from the answers file, and if it keeps them, whether re-adding the capability reuses them without asking (Trace C). Finding: dropped. Removing `container` took `docker_context` and `image_name` out of the answers file. Re-adding it with `--defaults` gave the default (`image`), not the earlier value (`docker`). Nothing stale is reused, but a non-default value has to be passed again or it's lost without warning. The removal merged cleanly in `dependabot.yml`, the CI stub and `.gitignore` (the repo's line by then followed `docs-astro`'s section). It conflicted in `extensions.json`, where the repo had appended after `vscode-docker`; the line before the removed item loses its comma, so it's pulled into the conflict too (C3).
- **E5. Questions asked only for one capability.** Whether Copier can ask the docs path only when `docs-astro` is declared, and whether `copier update` prompts for a new question or needs it passed in (Proposed map, Generator). Finding: a question with `when: "{{ 'docs-astro' in capabilities }}"` appears in the answers only once `docs-astro` is declared, and `--defaults` gives it its default. When a template release added a required question with no default, `copier update --defaults` failed with `Question "slack_channel" is required` and wrote nothing (X2). An interactive `copier update --skip-answered` asked only the new question.
- **E6. Copier tasks filling in versions at set-up.** Whether a Copier task can run `dotnet add package` and `npm install` at set-up, so the template never holds versions (UDF `:256`, V4 `:296`; A3, B5). Finding: works at set-up only. Tasks with `when: "{{ _copier_operation == 'copy' }}"` ran once during `copier copy`. `dotnet add package` wrote the newest versions into a manifest scaffold that had none, plus the lock file (`Invoke-Build` 5.14.23, `Pester` 6.2.0, `Brownserve.PSCommon` 0.2.1). On `copier update`, tasks run three times: in a replay of the old template version, in a render of the new one (both temp directories), and in the repo, with `_copier_operation` set to `update` each time. `_external_data` reads the answers file after Copier has rewritten it, so a task can't tell a capability was just added. A task that checks for the lock file itself (`[ -f pages/package-lock.json ] || npm install …`) installed Astro and wrote `package-lock.json` when `docs-astro` was added, and a later Dependabot bump to `package.json` survived the next update. But the check fails in both temp directories, so every later update runs `npm install` twice there. `dotnet add package` also marks Invoke-Build `PrivateAssets` (it's a development dependency) and leaves `.build/obj/` untracked (Paket V8).
- **E7. `dotnet restore --locked-mode`.** Whether it fails rather than rewriting the lock when the manifest and lock disagree (Paket `:93`, `:98`, V5 `:192`). Finding: confirmed. With the manifest changed and the lock not, `dotnet restore --locked-mode` failed with `NU1004` (exit 1) and left the lock alone. A plain `dotnet restore` rewrote the lock without warning, so `_init.ps1` has to pass `--locked-mode` every time.
- **E8. `Extends` worked out at run time.** Whether the build script can work out its `Extends` list from the project config (IBT V4, `:231`). Finding: yes. The `ValidateScript` block runs as an ordinary scriptblock (`Invoke-Build.ps1:439-447`), so it can read the capabilities from the project config and return one `prefix::path` for each. `$PSScriptRoot` is the build script's directory whatever the working directory. Taking a capability out of the config dropped its tasks, and an env var pointed every path at a working copy. A capability with no base script, or a missing config, failed before any task ran. Project-only tasks loaded from a separate file when it existed, so nothing in the build script was specific to the repo.
- **E9. Shared lists through `import` and `extends`.** Whether cSpell `import` and markdownlint `extends` can reach a shared file, the latter without npm (UDF `:96-97`, V6 `:298`). Finding: yes, from a file on disk. With the shared files in a restored package under `packages/`, markdownlint-cli2 0.23.3, cSpell 10.3.6 and both VS Code extensions applied them, and the repo's own cSpell words still counted. markdownlint `extends` takes a path or a Node module (npm), not a URL; a URL crashed the extension and the CLI. cSpell `import` loaded an HTTPS URL, but adding a word in the editor then crashed it every time. With the shared file missing, markdownlint crashed in both; cSpell failed the CLI run but carried on in the editor. The cSpell CLI doesn't read `.vscode/settings.json`, only files such as `cspell.json`, which the extension also reads. The editor's "add word" defaults to `.vscode/settings.json` and also offers the imported shared file, where a word is lost at the next restore. A workspace `cSpell.allowWordsToBeAddTo` (resource scope, so it can ship in `settings.json`) plus `"readonly": true` in the shared file left only the repo's `cspell.json` and the user dictionary. The extension inserts added words alphabetically. The CI actions (`DavidAnson/markdownlint-cli2-action` v24.2.0, `streetsidesoftware/cspell-action` v9.1.0) are bundled Node actions, so no repo needs npm; read from their `action.yml`, not run.
- **E10. Required check names through a reusable workflow.** Checks are expected to be named `<caller job> / <called job>` (GHA `:168`, V6 `:191`). Finding: confirmed on `copier-test`. Checks are `build / gate`, with one per matrix leg (`build / test (linux)`). A job skipped by `if:` reports `skipped`, and as a required context it passes. A required context nothing reports blocks the PR. Terraform's plain `contexts` matched; GitHub tied them to the Actions app itself.
- **E11. Permission ceiling for called jobs.** Whether GitHub fails a run when a called job asks for more than the caller grants, and whether that holds for a job skipped by `if:` (C2). Finding: yes, and skipped jobs too. The run fails at startup ("The nested job 'push' is requesting 'packages: write', but is only allowed 'packages: none'"), with the job switched off by `if:` as well.
- **E12. Dependabot groups and cooldown for Brownserve refs.** Whether Brownserve actions and packages can be grouped into one PR and excluded from the 30-day cooldown (GHA `:139`, V7 `:192`; Paket `:161`, V2 `:189`). Docs half: yes. `groups` `patterns` and `cooldown` `exclude` both take `*`, and `exclude` beats `include`. Dependabot's source matches them differently: group patterns ignore case, cooldown patterns don't (`File.fnmatch?`), so `exclude` has to match the case written in `uses:` or the `.csproj`. A reusable workflow's dependency name includes its path (`owner/repo/.github/workflows/x.yaml`), which `*` still matches. A group stays inside one `updates` entry, so Brownserve actions and packages come as one PR per ecosystem unless `multi-ecosystem-groups` is used. With no `cooldown` block Dependabot still waits 3 days. GitHub half: confirmed on `copier-test` for actions. A lowercase group pattern grouped both reusable workflows and the action into one PR. `exclude` in the case used in `uses:` let a same-day tag through; in lowercase it was held ("All versions are in cooldown period"). Cooldown reads tag dates, so no GitHub Release is needed. NuGet wasn't run.
- **E13. `setup-node` reading `node-version-file`.** Whether `setup-node` can take the Node version from `package.json`, leaving one owner (B3). Finding: yes. `node-version-file: package.json` reads `volta.node`, then `devEngines.runtime`, then `engines.node` (setup-node v7.0.0). The scaffold's `>=22.12.0` is a range, so CI gets the newest matching Node cached on the runner (or published, with `check-latest`), which moves with the runner image unless the scaffold pins a major. The path is resolved from the repo root, so the shared workflow needs the docs path as an input.
- **E14. Upstream Node dev container Feature.** Whether one exists that would need no Brownserve build (A7). Finding: yes. `ghcr.io/devcontainers/features/node` (2.1.0) installs Node, with the version as an option (default `lts`). It supports Debian- and RHEL-family images and exits on anything else; `bsdev`'s dev container is Ubuntu-based (`.devcontainer/Dockerfile:6`). Upstream Features also exist for PowerShell, Rust and Docker, so every capability's tooling has one.
- **E15. Project Pages under the org's custom domain.** Whether project sites are served under `docs.brownserve.co.uk`, the CNAME of the org Pages site (`repos.tf:111-113`) (Proposed map, Docs). Finding: confirmed. A project site with no custom domain of its own is served under the org site's (GitHub docs). Live, `brownserve-uk.github.io` has `cname` `docs.brownserve.co.uk`, and `PSCommon`'s site has none and serves at `https://docs.brownserve.co.uk/PSCommon/`. The path is the repo name, so a rename moves the site (T5).
- **E16. `license_template` behaviour.** Whether changing it later forces the repo to be replaced, and which name the copyright line uses (Proposed map, Docs). Finding: changing it doesn't replace the repo, and doesn't change `LICENSE` either. In provider 6.6.0 (the lock's version), `license_template` isn't `ForceNew`. Terraform never reads it back, and the repo edit API has no licence parameter, so a later change applies in place and does nothing. A throwaway repo created with `license_template: mit` got `Copyright (c) 2026 Brownserve`: the org's display name and the creation year.
- **E17. README scaffold vs `auto_init`.** `auto_init` already writes `README.md` (`modules/github-brownserve_repo/repository.tf:9`), so a Copier scaffold under `_skip_if_exists` would be skipped. Not checked against a Brownserve repo (Proposed map, Docs). Finding: confirmed with a stand-in for `auto_init`'s README: `copier copy` reported `README.md` as a conflict and skipped it. A later template change to a `_skip_if_exists` file never reached the repo either.
- **E18. CI app key as a Dependabot secret.** Variant G needs the App key as a Dependabot secret set by Terraform (UDF `:207`, V9 `:301`). Docs half: yes. A Dependabot-triggered run gets only Dependabot secrets. Provider 6.6.0 has `github_dependabot_organization_secret` with `selected` visibility, so the App key can follow `brownserve_ci_app_repos` like the Actions secret does (`apps.tf:90-96`), as a second resource on the same list. Whether a push with it triggers CI is still V9.
- **E19. Stub inputs and secrets against the pinned workflow.** Whether GitHub checks a stub's `with:` and `secrets:` against the workflow its pin names (X3). Finding: confirmed on `copier-test`. Three cases failed at startup with no jobs:
  - An input the workflow doesn't declare: "Invalid input, bar is not defined in the referenced workflow."
  - A required input left out: "Input req is required, but not provided while calling."
  - A secret passed explicitly that the workflow doesn't declare: "Invalid secret, mysecret is not defined in the referenced workflow."

  `secrets: inherit` to a workflow that declares no secrets ran fine. The error text shows only on the run's web page, not in `gh run view`. GitHub's workflow syntax docs say the same.
- **E20. Dependabot on Copier template source.** Whether the template repo's Dependabot can bump pins inside the template's own files (A4). Finding: only under narrow conditions.
  - From dependabot-core:
    - For a directory other than `/`, `github-actions` lists only that exact directory, with no `.github/workflows` lookup and no recursion (`github_actions/file_fetcher.rb#L90-L111`).
    - Files must be named `.yml` or `.yaml` (`constants.rb#L21`) and parse as YAML with a top-level `jobs` or `runs` (`workflow_file.rb#L26-L41`).
    - Updates are byte-offset edits, so comments survive.
  - Live on `copier-test`:
    - A `.jinja` suffix wasn't found.
    - `[% if %]` on its own line failed with `dependency_file_not_parseable`.
    - An entry at the template root found nothing (`dependency_file_not_found`).
    - It worked with four settings together: `_templates_suffix: ""`, the entry at the exact `template/.github/workflows`, control flow hidden in YAML comments (`line_statement_prefix: "#%"`), and variables in quoted values. Dependabot opened PRs and left the `#%` lines alone, and Copier 9.18.2 rendered the result.
    - Not tested: if/else branches that set the same key, which a YAML parse would collapse.
  - A pins file works with no constraint on the templates (local, Copier 9.18.2):
    - The pins file is a real workflow in the template repo (`.github/workflows/pins.yaml`, `on: workflow_dispatch`, every job `if: false`) that Dependabot bumps natively.
    - A template reads it with `[% include %]` and `regex_search`, which keeps the `# vX.Y.Z` comment (`from_yaml` drops it).
    - Copier's Jinja loader is rooted at the template repo (`_jinja_ext.py` L51-81, `_main.py` L712-734), so the include reaches it, and the pins file doesn't reach rendered repos.
    - `_external_data` can't read it, because it resolves against the destination (`_main.py` L330-370).
  - The test PRs on `copier-test` were closed, which may stop Dependabot proposing those versions there again.
- **E21. `exclude-paths` for `github-actions`.** Whether a repo's Dependabot can skip the stubs and still bump the maintainer's own workflows (A4). Finding: confirmed on `copier-test`.
  - With the stubs excluded by exact name and by glob, the PR touched only the maintainer's workflow ("Filtered from 7 to 5 entries").
  - It's set per `updates` entry and applies to version updates only (GA 2025-08-26).
  - Globs (`*`, `**`) are relative to the entry's directory and apply to directory listings only, and a bare `*` can cross `/` (`common/lib/dependabot/file_filtering.rb#L10-L67`).
  - Not established: whether security updates honour it.
  - `ignore: dependency-name` would hide Brownserve refs in every file instead.
- **E22. Dependabot and the dev container reference.** Whether any ecosystem bumps the image tag or Feature versions in `devcontainer.json`, in a repo or in the template (A4, A7). Finding: Features only.
  - `devcontainers` bumps Feature versions (`feature_dependency_parser.rb#L50-L102`) and finds the file in non-standard directories (`file_fetcher.rb#L27-L73`), but only if it's named exactly `devcontainer.json`.
  - It doesn't touch `image:`, and `docker` ignores `devcontainer.json`, so nothing bumps an image tag.
  - A `devcontainer.json` with Jinja in it ran green and opened no PR.
  - Not tested together: a plain `devcontainer.json` in the template repo bumped by `devcontainers`, read by the template the way E20's pins file is.
- **E23. A marker line under Copier's merge.** Whether a fixed comment the template never changes keeps repo lines below it out of conflicts (A8). Finding: confirmed with Copier 9.18.2.
  - Clean in `.gitignore`, JSONC (a `//` marker, the template's last entry with a trailing comma) and a Markdown checklist (`<!-- -->`): a release appending directly above the marker, adding `docs-astro`, and removing `container` when its section sat directly above the marker. Also clean in a `bsdev`-shaped `.editorconfig` that grew six lines above the marker, and in `dependabot.yml` with the marker at the end of `updates:`.
  - In Markdown the comment splits the checklist into two lists when rendered; markdownlint-cli2 0.23.3 reports nothing.
  - VS Code's "add to recommendations" (`workspaceExtensionsConfig.ts:149`) and the Settings UI append after the last element. With nothing below the marker they write above it; once a repo line is below it, they write below. Simulated with `jsonc-parser`, not run in the editor. With repo additions above the template's lines instead, editor writes always land in the template's part.
  - A marker with no final newline is changed by the first line appended below it, so a template addition directly above it conflicts.
  - Repo additions as answers: a hand-edited `.copier-answers.yml` doesn't reach the file on `copier update`, because the old version is rendered with the new answer too, so the line reads as a local deletion. `copier recopy` reaches it but drops every other local edit.
- **E24. How `copier update` merges.** What the merge does with repo edits inside and next to template lines (A8, X4). Finding, from Copier 9.18.2's source, then runs:
  - It renders the old version, diffs it against the repo's index (`git write-tree`), renders the new version over the repo, and applies the diff with `git apply --reject`. Only files with a rejected hunk go through `git merge-file`, which writes the inline markers (`copier/_main.py:1388-1699`).
  - The default context is 3 lines (`_main.py:267`), not 1 as the docs say (`docs/configuring.md:861`). `--context-lines` is a CLI flag only.
  - `git apply` finds a hunk by its context at any offset, so line numbers don't matter, and a hunk can apply in the wrong place when its context appears elsewhere (the docs warn of this, `configuring.md:870-872`).
  - Edits inside template sections: in `bsdev`'s `.editorconfig`, the PowerShell `indent_size` changed to 2 survived a release that grew the file and changed TOML, and the removal of either capability. A release adding a PowerShell property conflicted.
  - Moves with no conflict (X4):
    - A repo `ignore` rule in `dependabot.yml`'s `cargo` entry moved into the `github-actions` entry when `rust-app` was removed, with no marker, with identical per-entry markers, and with identical markers plus `--context-lines 5`. A unique marker per entry made it a conflict.
    - In an `.editorconfig` where removing `rust-app` dropped `[*.rs]` but kept `[*.toml]`, a repo line at the end of `[*.rs]` moved into the PowerShell section. `--context-lines 5` made it a conflict. Where `[*.rs]` and `[*.toml]` went together, the same kind of edit conflicted.
  - Without a marker, a repo entry at the end of `updates:` merged only when the template's new entry ended with the same lines; otherwise it conflicted.
  - Repo additions inside a template-owned `groups:` or `ignore:` conflicted when the template appended at the same point, and merged when its change was three or more lines away.
- **E25. Promotion and duplicates.** Whether a repo line the template later adopts merges, and what the readers do with two copies (A8, X5). Finding: both copies are kept.
  - Below a marker, an identical promotion merged cleanly in `.gitignore`, `.editorconfig`, `extensions.json`, `settings.json`, a Markdown checklist and `dependabot.yml`, leaving two copies. A promotion with a different value did the same, with the repo's copy last. A repo line exactly where the template later adds the same text merged to one copy; with different text it conflicted.
  - Readers:
    - `.gitignore`: the last match wins; harmless.
    - `.editorconfig`: later sections win (spec 0.17.2), with no warning (`editorconfig` npm 3.0.2).
    - `settings.json`: the last key wins at runtime (`base/common/json.ts:847-857`), and the editor warns "Duplicate object key" on both (`jsonParser.ts:1525-1529`).
    - `extensions.json`: deduped at runtime (`workspaceExtensionsConfig.ts:84`), with no warning. "Remove from recommendations" removes only the first copy (`:303-306`).
    - Markdown: harmless and visible; markdownlint has no rule for it.
    - Trailing commas raise no warning in either VS Code file: both schemas set `allowTrailingCommas` (`jsonValidation.ts:87-88`).
  - A `_migrations` entry gated on the version being crossed (`new >= version > old`, `configuring.md:1428-1500`) removed the exact copies in all six files, run `after`, or `before` with `git add` (the diff reads the index, so unstaged edits are lost). It needs `--trust` and removes only identical copies. Not tested: a migration failing partway.
  - A repo-owned sidecar read with `_external_data` doesn't help: the old and new renders can't see it, so promoted entries conflicted.
- **E26. Dependabot per-repo variation.** Whether a repo can add entries, ignores and groups next to the template's, and what Dependabot does with duplicates (A8, X5). Finding, from GitHub's docs and dependabot-core:
  - Two entries with the same ecosystem, directory and target branch, or overlapping `directories`, are rejected: "Update configs must have a unique combination of 'package-ecosystem', 'directory', and 'target-branch'." (quoted in rust-random/getrandom#620). The check is in GitHub's closed service. A different `target-branch` is allowed.
  - Duplicate keys in one entry: not established. GitHub parses the file in closed code. dependabot-core's own parser is Psych (`config/file.rb:52`), last-wins, used only by its dry-run script. A last-wins parser would drop the template's `ignore` or `groups`.
  - `groups`: a dependency goes to the first group it matches, so a repo group after the template's gets only what's left.
  - `ignore` beats `allow`. The docs say it covers version and security updates, but `update-types` doesn't apply to security updates, and in dependabot-core a security job honours only `versions` ranges (`ignore_condition.rb:41-45`). Whether the service filters name-only ignores is open.
  - `@dependabot ignore` comment commands are stored by GitHub, not in `dependabot.yml`, and reach jobs as ignore conditions with a version range, which security jobs honour. Listed with `@dependabot show <dependency> ignore conditions`; undone by reopening the PR or with `@dependabot unignore`. They aren't version-controlled, and Copier never sees them.
  - No include, extends or second-file mechanism.
- **E27. Resolving a conflict in the sync PR.** Whether a conflict can be resolved one way or the other without editing the file by hand, once the sync has committed it (A8). Finding, from Copier 9.18.2's and VS Code's source, then runs:
  - Copier's `--conflict` takes only `inline` or `rej` (`copier/_cli.py:398-403`). It writes the markers with `git merge-file` (`<<<<<<< before updating`, `>>>>>>> after updating`) and records the conflict in the index (`_main.py:1622-1691`). In the S5 repo `git status` showed `UU .editorconfig`, with the old render, the repo's file and the new render as stages 1 to 3.
  - Locally, straight after `copier update`, the merge editor and `git mergetool` work. `git checkout --theirs` takes the new render whole, dropping every repo line including those below the marker; `--ours` drops the template's update to that file. `git merge-file --ours`, `--theirs` or `--union` on the stages settles only the conflicting hunks: on S5, `--ours` kept the repo's Rust and TOML sections and `--theirs` took the template's removal.
  - Committing the markers clears the stages, and GitHub's "Resolve conflicts" covers only conflicts with the base branch.
  - VS Code's built-in merge-conflict extension finds conflicts in the text, not through git (`extensions/merge-conflict/src/mergeConflictParser.ts:10-13,44-66`), and has a browser build (`package.json:26`), so it should run in github.dev. Copier's markers match its format. Current is the repo, Incoming the template.
  - github.dev's commits are signed, which branch protection requires (the maintainer's regular practice).
  - Not run: resolving in github.dev itself.
- **E28. Replacing a file whole on update.** Whether a file can be reset to the template's render on every `copier update`, as the generator does today (A9). Finding, from Copier 9.18.2's source and markdownlint, then runs: yes, with a migration.
  - No setting does it. `_skip_if_exists` protects the repo's copy, `--overwrite` only skips prompts, and `copier recopy` resets the whole project.
  - A repo's `.markdownlint.json` wins over a shared base: over `--config` in markdownlint-cli2 0.23.3 (the repo's MD013 fired with a base turning it off), and over the extension's `markdownlint.configFile` (readme, 0.62.1). Nested files override too.
  - Tasks run while the new version renders into the repo, before the diff is replayed (`_main.py:1472`, `:1588`), so the merge undid a task's rewrite.
  - A `_migrations` entry with no `version` runs `after` on every update, once the diff is applied (`_template.py:439-471`, `_main.py:1695-1699`), if both template versions are tagged (`_template.py:411`). A list-form command renders each part with Jinja and runs without a shell (`_main.py:413-421`), so an `{% include %}` of the file's `.jinja` source passes the render, with the current answers, to `_copier_python`.
  - Runs: a temporary edit to `.markdownlint.json` and `.editorconfig` was reset byte-identical to a fresh `copier copy` with the same answers, on a release that conflicted with the edit (no markers left, git still `UU`), on a release that also removed `container`, and on a `--vcs-ref=:current:` update adding it back.
  - Not run: on Windows, or in the sync workflow.
- **E29. Dev container base image tag and baseline Features.** Whether the stock base image publishes a tag that takes rebuilds without a pin change, whether an upstream .NET Feature covers the build, and whether the PowerShell, .NET, Rust, Docker and Node Features install together on that base (A7, 3.6). Not checked.
- **E30. Node version checks for `docs-astro`.** Whether Astro refuses to start on a Node outside its supported range, whether Dependabot `npm` leaves `engines.node` alone, and whether the Node Feature accepts a major such as `"22"` (B3, 3.7). Not checked.
- **E31. Lock file commands for Cargo and npm.** On a copy of `bsdev` bumped from 0.10.0 to 0.11.0: `cargo generate-lockfile` moved 20 third-party crates; `cargo update --workspace` moved only `bsdev` and `bsdev-core`; Cargo with `--locked` exits 101 against the stale lock. `npm ci` fails with no lock, and with a lock missing a dependency in `package.json` (T3, B4, 3.8). Confirmed. Whether Dependabot `npm` updates `package-lock.json` in the same PR as `package.json`: not checked.
