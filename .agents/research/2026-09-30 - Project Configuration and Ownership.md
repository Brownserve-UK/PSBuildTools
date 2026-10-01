# 2026-09-30 - Project Configuration and Ownership

> **Work in progress.** This document is being built up one area at a time, possibly across several sessions. Nothing here is decided until the final pass.

Follows the research phase of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).

## Status

**Phase 1: Inventory.** All groups drafted. Next: review the whole inventory, then start Phase 2.

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

This is being done slowly and carefully to assess each area in turn with the user to ensure direction is aligned and help guide towards the correct shape.
Three phases. Each finishes with a stable output before the next starts, so work can be handed off between sessions.
File edits must be agreed with the user before writing.

1. **Inventory (facts only).** Every piece of information the `rust` and `container` capabilities involve in `bsdev` today: where it's stated (every place), what reads it, what writes it, when it changes. No proposals, no owners. Complete when every group has been checked against the sources below and reviewed.
2. **Change traces (facts plus research proposals).** For each change (declare `rust` + `container`, add a capability, remove `container`): which inventory rows change, which files must change, and where each research doc's proposal would leave more than one source of truth or an unclear writer. No decisions. Complete when every conflict is listed.
3. **Decisions.** One conflict at a time, each set out as: question, today, readers, options (with consequences for `bsdev` on declare, add and remove), knock-on for the research docs, recommendation and confidence. Whether a declaration exists, what it holds and where it lives are decided last.

Rules:

- Every fact carries a file reference so anyone can check it.
- Decisions rely only on earlier ones. If a later finding shows an earlier decision was wrong, it's reopened explicitly.
- The Status section is updated at the end of each session.
- No git history of Brownserve repositories is consulted (per the brief).
- This document is not updated until the user agrees to it

Sources checked:

- `bsdev`: `~/host-repos/Brownserve/bsdev`
- The generator: `Module/Private/Build/Compare-BrownserveRepository.ps1`, `Module/Private/.config/`, `Module/Private/Build/templates/`
- Terraform: `~/host-repos/Brownserve/Terraform/GitHub`

## Phase 1: Inventory

In progress.

Files are grouped by the part of the repository that reads them. Each group has a table with one row per file and these columns:

- **Holds:** the information in the file.
- **Comes from:** where that information comes from today.
- **Written by:** who writes the file today.
- **Read by:** what uses the file.
- **Changes when:** what causes the file to change.

Information stated in more than one file shows up as repeats across rows.

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

**Repeats so far:**

- Binary name: `build.ps1:177`, `Basic.Binary.Tests.ps1` (four times), and the default in `build_tasks.ps1:19`.
- Repo name: worked out at run time in `_init.ps1:64`, and baked in by the generator elsewhere.
- Owner: `build.ps1:69`.

### CI workflows

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.github/workflows/builds.yaml` | Runs on PRs to `main`. Change filters for Rust/build paths (`Cargo.toml`, `Cargo.lock`, `*.rs`, `.build/`, `.config/`, `nuget.config`, `:28`) and for `image/` (`:35`); OS matrix (`:49`); repo name `bsdev` (`:59`, `:65`, `:84`, `:90`); build targets `BuildTestAndCheck` (`:67`) and `BuildImage` (`:92`); a gate job named `BuildTestAndCheck` (`:98`); action pins (`:57`, `:82`) | `bsdev_github_builds.yaml.template` with the repo name filled in. Matches apart from the action pins | The generator, whole file (`:1824`, `:1863-1876`); Dependabot (`github-actions`) for the pins | GitHub Actions; Terraform requires a check named `BuildTestAndCheck` (`repos.tf:211`) | A regeneration, which would put the pins back to the template's older SHAs; a Dependabot pin bump |
| `.github/workflows/stage-release.yaml` | Manual trigger with a `release_type` input (`:5-14`); repo name (`:34`, `:48`); Rust toolchain install for `UpdateCargoVersion` (`:39`); target `StageRelease`; CI app secrets (`:28-29`) | `rustapp_github_stage-release.yaml.template`, which `bsdev` shares with `RustApp` (`:749`), with the repo name filled in. Matches apart from the action pin | The generator, whole file; Dependabot for the pins | GitHub Actions (manual dispatch) | A regeneration; a Dependabot pin bump |
| `.github/workflows/release.yaml` | Manual trigger with a `publish_to` input that defaults to GitHub, GHCR, DockerHub (`:5-10`); a matrix of OS and Rust target triples (`:19-25`); targets `Package` and `Release`; artifact name `binary-*` and path `bsdev/.tmp/output/` (`:50-51`, `:80`); `packages: write` for GHCR (`:61`); secrets: CI app (`:68-69`), `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` (`:89-90`), `SLACK_WEBHOOK_BUILD` (`:110`); `GITHUB_TOKEN` for GHCR (`:88`) | `bsdev_github_release.yaml.template` with the repo name filled in. Differs by more than pins: the `publish_to` input and `PublishTo = ${{ inputs.publish_to }}` (`:96`), where the template hard-codes `@('GitHub', 'GHCR', 'DockerHub')` | The generator, whole file; Dependabot for the pins; the maintainer, for `publish_to` (a fix made in place, never carried back to the template) | GitHub Actions (manual dispatch) | A regeneration, which would drop `publish_to` and put the pins back; a Dependabot pin bump |
| `.github/workflows/label-pr.yaml` | Mapping from PR title prefix to changelog label (`:79-90`); labelling for Dependabot PRs (`:93-119`); skips `release/` branches (`:73`); job name `label-pr` | `psmodule_github_label-pr.yaml.template`, no substitutions (`New-BrownserveGitHubLabelPRWorkflow.ps1:11`). Content is identical. Every project type that has workflows gets it (`:409`, `:470`, `:526`, `:613`, `:712`, `:805`) | The generator, whole file (`:1910-1937`); Dependabot could bump the `github-script` pin, which still matches the template | GitHub Actions (`pull_request_target`); Terraform requires a check named `label-pr` (`repos.tf:211`) | A regeneration picks up a template change; a Dependabot pin bump |

**Secrets the workflows read:**

- `BROWNSERVE_CI_APP_ID` and `BROWNSERVE_CI_APP_PRIVATE_KEY` are org secrets shared with selected repos, including `bsdev` (`apps.tf:52-53`, `:90-96`).
- `SLACK_WEBHOOK_BUILD` is an org secret visible to every repo (`secrets.tf:74`, `:178-183`).
- `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` were set by hand (see above).
- `bsdev` also gets `GH_TOKEN_RELEASE`, `GH_TOKEN_STAGE_RELEASE` and `GPG_KEY_AUTOMATED_BUILD` (`secrets.tf:131`, `:186-192`). None of its workflows read them.

**Repeats added:**

- Repo name: written into the workflows nine more times.
- Docker context `image/`: `builds.yaml:35`, and the default in `build_tasks.ps1:131`.
- Rust target triples: `release.yaml:21-25`, `install.ps1:25`, `install.sh:26`, `:32`.
- Publish destinations: `release.yaml:9`, the `ValidateSet` in `build.ps1:59`, and a hard-coded list in the release template.
- Build target names: the workflows call `BuildTestAndCheck`, `BuildImage`, `Package`, `Release` and `StageRelease`, so these must exist in `build.ps1:28-36`.
- Required check names: the `BuildTestAndCheck` and `label-pr` jobs, and `repos.tf:211`.
- Changelog labels: `label-pr.yaml:79` and Terraform `modules/github-brownserve_repo/issues.tf`. They don't match (see Open questions).

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

**Repeats added:**

- Docker context `image/`: `dependabot.yml:19`, from the generator at `:729`. Three places in total.
- Binary name: `cli/Cargo.toml:7`, which must match `BinaryName`.
- Version: `Cargo.toml:6`, twice in `Cargo.lock`, and the latest `CHANGELOG.md` entry (`:10`). `UpdateCargoVersion` keeps them in step.

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

**Repeats added:**

- Extension list: `extensions.json` and `devcontainer.json:11-19`, both written from one list in the same run (`:1144`).
- Ubuntu focal: `devcontainer.json:5`, `Dockerfile:5`, and the `ubuntu/20.04` package URL (`Dockerfile:19`).
- Rust and container each show up in three configs: extensions (`rust-analyzer`, `even-better-toml`, `vscode-docker`), editorconfig sections (`*.rs`, `*.toml`, `Dockerfile`), and the devcontainer, which has the Rust toolchain but no Docker tooling.
- PowerShell formatting settings: copied into five type entries in `repository_vscode_extensions.json` (`:31-39`, `:60-70`, `:93-104`, `:115-126`, `:137-148`). Generator-side, not in `bsdev`.

### Repository hygiene

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.gitignore` | Paket files and `.tmp/` (`:6-11`); AI tool directories (`:14-19`); Rust: `target/` and `**/*.rs.bk` (`:22-25`); container: `.docker/` (`:28`); a manual section (`:30`) | `gitignore_config.json`: defaults (`:2-26`) plus `bsdev` (`:50-63`). Matches exactly. `bsdev`'s list is `RustApp`'s plus `.docker/`, which it shares with `WebApp` | The generator, apart from the manual section after `## Manually defined ignores: ##`, which it keeps (`:308-320`, `:1372-1397`). If that marker is missing, the file is reported as unparsable and generation stops unless `-Force` is used (`:319`, `:882-890`) | Git | A regeneration picks up a config change; the maintainer edits the manual section |
| `.markdownlint.json` | `MD013` off; `MD024` siblings only | `markdownlint_config.json`, which is one config for every type, with no per-type entries. Matches exactly | The generator, whole file. It deliberately overwrites local changes "for a consistent gold standard" (`:1704-1748`) | markdownlint (VS Code extension) | A regeneration picks up a config change |

`.docker/` is ignored, but nothing in `bsdev`'s `.build/` or `.github/` creates it. It comes along with the container config entry.

`.markdownlint.json` is the first file deliberately identical across every type, with no local customisation allowed. Neither `rust` nor `container` affects it.

**Repeats added:**

- Ephemeral paths: `.tmp/` and `paket.lock` are ignored here and also wiped and recreated by `_init.ps1` (`:77-79`).
- Cargo.lock: "intentionally NOT ignored" (`:21`), matching the Dependency tooling row.

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

Only `rust` shows up in the generated docs (CONTRIBUTING prerequisites, both files' cargo commands). Neither generated doc mentions `container`: there's no `BuildImage` or Docker step in either. The image only appears in the maintainer-owned `README.md` and `CLAUDE.md`.

`New-SPDXLicense` runs on every regeneration (`:1216-1222`) even though its output is only used when `LICENSE` is missing, so every regeneration needs to reach GitHub.

**Repeats added:**

- Owner and repo name: `README.md` install URLs, every `CHANGELOG.md` entry link, `LICENSE`, and the PR template.
- Conventional Commits prefix table: `CONTRIBUTING.md:36-42`, and the title mapping in `label-pr.yaml:79-90`.
- Changelog labels: `New-BrownserveChangelogEntry -Auto` sorts entries by the labels `label-pr.yaml` applies (confirmed by the maintainer), so the `removed`/`removal` mismatch reaches the changelog too.
- Build commands (`cargo build`, `cargo test`, `BuildTestAndCheck`): `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, the PR template.
- Scaffold contract (binary name, `[workspace.package]` version): restated in `CLAUDE.md`.

### Install scripts

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `scripts/install.sh` | Owner, repo and binary name (`:7-9`), with the binary set to the repo name; the latest release tag from the GitHub API (`:11-13`); OS/arch to target triple: Linux `x86_64` and macOS `arm64` only (`:23-40`); asset name `<binary>-<tag>-<triple>.tar.gz` (`:42`); install paths (`:53-61`) | `rustapp_install.sh.template` with `OWNER` and `REPO_NAME` filled in (`:770-776`, `:2229-2236`), which `bsdev` shares with `RustApp` (`:670-674`). Matches | The generator, whole file, whenever it differs (`:2218-2280`) | People, through the one-liner in `README.md:31`, which fetches it from `main` | A regeneration picks up a template, repo name or owner change |
| `scripts/install.ps1` | Owner, repo and binary name (`:13-15`); the latest release tag from the GitHub API (`:17-18`); a single target `x86_64-pc-windows-msvc` (`:25`); asset name `<binary>-<tag>-<triple>.zip` (`:26`); install paths and PATH update (`:42-62`) | `rustapp_install.ps1.template`, same substitutions (`:777-781`). Matches | The generator, whole file, whenever it differs | People, through the one-liner in `README.md:36` | Same as `install.sh` |

Neither script is touched by `container`. They rely on what the `rust` capability's release produces: `Package` names archives `<BinaryName>-v<version>-<triple>` with `.zip` on Windows and `.tar.gz` elsewhere (`build_tasks.ps1:577`, `:584`), and `PublishRelease` uploads them as release assets (`:627-649`). The scripts have no check that these names agree; a mismatch only shows up when someone runs the installer.

The template fills `BINARY` from the repo name, but the build takes `BinaryName` as a parameter (`build.ps1:177`, default repo name at `build_tasks.ps1:19`). If the two ever differ, the installers would look for an asset that doesn't exist.

**Repeats added:**

- Owner, repo and binary name: both scripts.
- Rust target triples: the installers each list a subset by hand (`install.sh:26`, `:32`; `install.ps1:25`), separate from `release.yaml:21-25`. All three match today.
- Release asset naming: `Package` (`build_tasks.ps1:577`, `:584`) and both installers (`install.sh:42`, `install.ps1:26`).

### Generator

| File | Holds | Comes from | Written by | Read by | Changes when |
| --- | --- | --- | --- | --- | --- |
| `.brownserve_repository_manifest` | `RepositoryType: bsdev` and `ManifestVersion: 1.0.0` (`:2-3`) | Built in code, with no config file (`:370-373`). `RepositoryType` is the `-ProjectType` passed to `Initialize-BrownserveRepository` (`:14-15`, `:98`), one of the `BrownserveRepoProjectType` enum values (`Module/Private/Classes.ps1:564-573`) | The generator, whole file, whenever it differs (`:1245-1280`) | `Update-BrownserveRepository`, which takes the project type from it (`:81-95`, `:121`); `Compare-BrownserveRepository`, which refuses a different type without `-Force` (`:222-246`); `Get-BrownserveRepositoryPaths` (`:30-43`), which nothing in the PSTools repos, `bsdev` or Terraform calls | Only by running `Initialize-BrownserveRepository -Force` with a different type |

This is the only place a repository says what it is. Everything generated in the groups above follows from this one value plus the generator's built-in settings for each type.

It doesn't record the owner or repo name. Each run gets them again: the owner from the `-Owner` default `Brownserve-UK` (`Update-BrownserveRepository.ps1:14`), and the repo name from the directory name unless `-RepoName` is passed (`Compare-BrownserveRepository.ps1:42-46`, `:1995-1998`). Running `Update-BrownserveRepository` from a clone in a directory with a different name would bake that name into every generated file that uses it.

`ManifestVersion` is written but nothing reads it.

**Repeats added:**

- Project type: the manifest, and the `bsdev` branch of the generator's type switch (`:690-783`), which hard-codes every per-type choice listed in the groups above.

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

Nothing in Terraform depends on `rust` or `container`. `container` shows up only in settings that are outside Terraform: the hand-set Docker Hub secrets, and GHCR, which works off the workflow's own token. So today, adding or removing a capability changes nothing in Terraform.

Every link between a setting and `bsdev` is by name only (check names, label names, secret names), and nothing checks that the two sides agree. The `removed`/`removal` mismatch is one that has already drifted.

**Repeats added:**

- Repos that take part in releases: `secrets.tf:125-134`, `apps.tf:34-63` and `teams.tf:10-47`. These are three hand-maintained lists that mostly overlap, and `bsdev` is in all three.
- Owner `Brownserve-UK`: `provider.tf:32`.

## Phase 2: Change traces

Not started.

## Phase 3: Decisions

Not started.

## Open questions

- **`removed` vs `removal` label.** `label-pr.yaml:88` applies `removed`, but Terraform defines `removal` (`modules/github-brownserve_repo/issues.tf:93`). Terraform's labels are authoritative (`issues.tf:2-3`). This isn't specific to `rust` or `container`, but it's two sources of the same information that disagree. The changelog groups entries by these labels, so the mismatch reaches `CHANGELOG.md` too.
- **Dependabot `docker` entry may do nothing.** `image/Dockerfile:8` uses `archlinux:latest` with no version or digest. Dependabot bumps versioned tags or digests, so this entry (`dependabot.yml:18-23`) probably never opens a PR. Not verified.
- **Dependabot ecosystem labels.** Terraform has `dependencies` and `github_actions`, but no label for `cargo` or `docker` (`issues.tf:56-97`). Because the label set is authoritative, any label Dependabot creates would be deleted on the next apply. Not verified.
- **Org `CODE_OF_CONDUCT.md` not verified.** `bsdev`'s PR template links to it in the `.github` repo (`repos.tf:123`), which isn't checked out locally.
