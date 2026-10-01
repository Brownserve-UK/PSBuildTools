# 2026-09-30 - Project Configuration and Ownership

> **Work in progress.** This document is being built up one area at a time, possibly across several sessions. Nothing here is decided until the final pass.

Follows the research phase of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).

## Status

**Phase 2: Change traces.** 2.3 in progress, Trace A (declare `rust-app` + `container`): declaration, Build, CI workflows, Dependency tooling, Dev environment, Repository hygiene and Docs done. Next: Install scripts.

- [x] 1. Inventory
- [x] 2.1 Agree the map format
- [x] 2.2 Today's map, built from the Phase 1 inventory
- [ ] 2.3 Trace A: declare `rust-app` + `container`, filling in the proposed rows it reaches
- [ ] 2.4 Extra inventory for `docs-astro`, plus its rows in today's map
- [ ] 2.5 Trace B: add `docs-astro`, filling in its proposed rows
- [ ] 2.6 Trace C: remove `container`
- [ ] 2.7 Problem list: duplicates removed, dependencies noted, order agreed for Phase 3
- [ ] 3.x Decisions: one problem per step, each fixing a row of the proposed map. The declaration (whether it exists, what it holds, where it lives) comes last
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
| **Sync mechanism** | Whatever brings shared files in a repository up to date with their central source. Provisionally Copier, per [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md). |
| **Local customisation** | A change the maintainer makes in one repository to a file that comes from somewhere shared, e.g. extra cSpell words, a manually defined `.gitignore` entry. Dependabot's edits are tracked separately. |
| **Map** | A table of where each piece of content in a repository comes from and how it gets there. Phase 2 builds one for today and one proposed. |
| **Route** | How content gets from where it comes from to where it's used, e.g. the generator, a Dependabot PR, a hand edit. Each piece of content should have exactly one. |
| **Problem** | A map row marked ⚠: two routes into the same thing, a route with no clear writer, or something that needs to change but has no route. |
| **Change trace** | Phase 2's record of one change (declare, add, remove): which source it changes, the map rows reached by following the routes out of it, and the problems found. |

## Method

This is being done slowly and carefully to assess each area in turn with the user to ensure direction is aligned and help guide towards the correct shape.
Three phases and a final pass. Each finishes with a stable output before the next starts, so work can be handed off between sessions.
File edits must be agreed with the user before writing.

1. **Inventory (facts only).** Every piece of information the `rust-app` and `container` capabilities involve in `bsdev` today: where it's stated (every place), what reads it, what writes it, when it changes. No proposals, no owners. Complete when every group has been checked against the sources below and reviewed.
2. **Change traces (facts plus research proposals).** Build today's map from the inventory, then trace three changes: declare `rust-app` + `container`, add `docs-astro`, remove `container`. Each trace fills in the proposed map rows it reaches from what the research docs propose. No decisions. Complete when every problem is listed and their order for Phase 3 is agreed.
3. **Decisions.** One problem at a time, each fixing a row of the proposed map, set out as: question, today, readers, options (with consequences for `bsdev` on declare, add and remove), knock-on for the research docs, recommendation and confidence. Whether a declaration exists, what it holds and where it lives are decided last.
4. **Final pass.** Settle the final map and unresolved questions. Re-run the three traces against the final map; anything still ambiguous reopens a decision or becomes an unresolved question. Proposed rows no trace reached are filled in or marked as unaffected by capabilities.

Map format:

- A list of sources first, each named once: the distinct values of the **Comes from** column.
- One table per area, using the Phase 1 groups, with three columns: **Thing**, **Comes from**, **Gets there by**.
- A row is a file, or part of a file where the parts arrive by different routes.
- ⚠ marks a problem. Problems are listed under the map with an ID.
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
- **Changelog labels** (CI workflows, Docs, GitHub settings): `label-pr.yaml:79` and `issues.tf:8-97`. `New-BrownserveChangelogEntry -Auto` sorts entries by the labels `label-pr.yaml` applies (confirmed by the maintainer). They disagree (see Open questions), and the mismatch reaches `CHANGELOG.md`.
- **Conventional Commits prefix table** (Docs): `CONTRIBUTING.md:36-42`, the title mapping in `label-pr.yaml:79-90`, and the "label missing" comment the workflow posts (`label-pr.yaml:171-184`).
- **Release-participating repos** (GitHub settings): `secrets.tf:125-134`, `apps.tf:34-63` and `teams.tf:10-47`. Three hand-maintained lists that mostly overlap; `bsdev` is in all three.
- **Project type** (Generator): `.brownserve_repository_manifest:2`, and the `bsdev` branch of the generator's type switch (`:690-783`).
- **Extension list** (Dev environment): `extensions.json` and `devcontainer.json:11-19`, written from one list in the same run (`:1144`).
- **Ubuntu focal** (Dev environment): `devcontainer.json:5`, `.devcontainer/Dockerfile:5` and the `ubuntu/20.04` URL (`:19`).
- **Rust and container dev config** (Dev environment): each shows up in three places: extensions, `.editorconfig` sections, and the devcontainer (Rust toolchain only).
- **Ephemeral paths** (Repository hygiene): `.tmp/` and `paket.lock` are ignored in `.gitignore` and wiped and recreated by `_init.ps1:77-79`.
- **`Cargo.lock` committed** (Repository hygiene, Dependency tooling): `.gitignore:21`.
- **PowerShell formatting settings** (Dev environment): five type entries in `repository_vscode_extensions.json` (`:31-39`, `:60-70`, `:93-104`, `:115-126`, `:137-148`). Generator-side, not in `bsdev`.

## Phase 2: Change traces

In progress.

### Today's map

References for each row are in the matching Phase 1 table.

**Sources**

| Source | What it is |
| --- | --- |
| **Generator** | PSBuildTools templates, config files and code, selected by the `bsdev` project type. Repo name and owner are filled in at run time. |
| **Maintainer** | Anything written by hand in `bsdev`, including by AI agents. |
| **Upstream** | New releases of actions, crates and base images. |
| **Cargo** | Dependency resolution from the `Cargo.toml` files. |
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
| `image/Dockerfile`, base image tag | Upstream | Dependabot PR (may do nothing, see Open questions) |

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
| `.brownserve_repository_manifest` | Maintainer (the `-ProjectType` argument) | Regen (`Initialize-BrownserveRepository`) |

**GitHub settings**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Required checks, labels, branch protection | Terraform | Terraform apply |
| CI app install and its secrets | Terraform | Terraform apply |
| `SLACK_WEBHOOK_BUILD` | Terraform | Terraform apply |
| `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` | Maintainer | Hand-set in GitHub |
| GHCR push access | Generator | Regen (`packages: write` in `release.yaml`) |

Not mapped, because they aren't committed: `paket.lock`, `packages/`, `.tmp/`, `target/`.

**Problems**

- **T1. Action pins arrive by two routes.** Dependabot bumps the pins in all four workflows, and a regeneration puts the template's older pins back (`builds.yaml:57`, `:82`; `Compare-BrownserveRepository.ps1:1863-1876`).
- **T2. Hand edits inside files the generator replaces whole.** These are the `publish_to` input in `release.yaml` (`:5-10`, `:96`) and the extra tests at `Basic.Binary.Tests.ps1:38-47`. A regeneration drops both.
- **T3. `Cargo.lock` moves outside Dependabot.** On every staged release, `UpdateCargoVersion` runs `cargo generate-lockfile` (`build_tasks.ps1:330`), which moves every dependency to its latest compatible version without a Dependabot PR.
- **T4. The Paket version has no update route except a hand edit.** It's only written when the file is missing (`Compare-BrownserveRepository.ps1:1326`), and `bsdev` has no Dependabot `nuget` entry. The PowerShell module types do have one (`:426`, `:488`).

### Proposed map

Filled in by the traces. Group names match today's map so the two line up. References are to the research docs: [Updating Distributed Files](./2026-09-30%20-%20Updating%20Distributed%20Files.md) (UDF), [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) (IBT), [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md) (GHA) and [Paket](./2026-09-30%20-%20Paket.md).

Unlike today's map, a row is also given to anything that replaces a file committed today, even if the replacement isn't committed (e.g. the shared tasks, restored into `packages/`).

**Sources**

| Source | What it is |
| --- | --- |
| **Maintainer** | Anything written by hand in the repo, including the answers given to Copier. |
| **Template** | The Copier template repo, released with version tags (UDF `:133`). |
| **Task package** | The shared build tasks, one base script per capability (IBT `:85`), plus the stock Pester tests, which read the binary name from the project config (UDF `:92`). |
| **Shared workflows** | The Tier 2 reusable workflows, which call the Tier 1 actions (GHA `:53-79`). |
| **Upstream** | New releases of packages (the task package, the Brownserve modules, Invoke-Build, Pester), of the shared workflows, and of crates and base images. |
| **NuGet** | Dependency resolution from the dependency manifest. Same role as Cargo. |
| **Cargo** | Dependency resolution from the `Cargo.toml` files. |
| **Release history** | The previous version, the release type and the PRs merged since. |
| **Terraform** | The repo's module call in the Terraform repo. |

**Routes**

| Route | What it does |
| --- | --- |
| **`copier copy`** | Runs once, when the repo is set up. Copier asks the maintainer its questions, fills in the template, and writes the files plus `.copier-answers.yml` (UDF `:127`, `:266`). |
| **`copier copy` (scaffold)** | Written once at set-up; template updates never touch it again (`_skip_if_exists`, UDF `:138`). |
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

Versions and the lock file each have two routes, but at different times: the Copier task runs once at set-up, and Dependabot acts after that. Local builds aren't a third route, because `dotnet restore --locked-mode` fails rather than rewriting the lock (Paket `:93`, `:98`; not verified, V5 `:192`). The Dependabot route needs a `nuget` entry in `dependabot.yml`, covered under Dependency tooling.

Retired: `paket.dependencies`, and the Paket entry in `.config/dotnet-tools.json` (Paket `:170`). Paket is the only entry in `bsdev`'s file (see the Phase 1 Build table), so the whole file goes.

**CI workflows**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| Shared workflow logic (today's jobs: matrices, build steps, gate job, artifacts, Slack) | Shared workflows | Workflow call |
| Stubs (`ci`, `pr-checks`, `stage-release`, `release`), everything except the pin | Template | `copier copy` |
| `release` stub, `publish_to` input ⚠ A5 | Template | `copier copy` |
| Template sync stub | Template | `copier copy` |
| Stub pins ⚠ A4 | Template (first pin); Upstream | `copier copy`; Dependabot PR |

References: tiers and stub contents (GHA `:53-64`, `:85-88`, `:108`); stub ownership, template except the pin (UDF `:89`, `:262`); lifecycle workflows (GHA `:119-121`, D3); `label-pr` as its own workflow or folded into `pr-checks` (GHA D7, `:180`); template sync stub (UDF `:235`). Inputs reach the build as environment variables (IBT `:170`), which removes the script injection in today's `publish_to` (GHA `:32`).

- **Repo name:** the shared workflow does the checkout, so the stubs don't need it. Whether the checkout still has to use a folder named after the repo is open (GHA `:19`, C4 `:160`).
- **Required checks:** through a reusable workflow a check is named `<caller job> / <called job>` (GHA `:168`, V6 `:191`). Covered under GitHub settings.
- **Dependabot:** the `github-actions` entry exists today; Brownserve refs need excluding from the 30-day cooldown (GHA `:139`). Covered under Dependency tooling.

**Dependency tooling**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `dependabot.yml` | Template | `copier copy` |
| Root `Cargo.toml`, members and edition ⚠ A6 | Maintainer | Hand edit |
| Root `Cargo.toml`, `[workspace.package]` version | Release history | Staged release |
| `cli/` and `core/` `Cargo.toml`, packages, binary name, dependency list ⚠ A6 | Maintainer | Hand edit |
| `cli/` and `core/` `Cargo.toml`, dependency versions | Upstream | Dependabot PR |
| `Cargo.lock` ⚠ T3 | Cargo | Cargo build; Dependabot PR; Staged release |
| `image/Dockerfile` ⚠ A6 | Maintainer | Hand edit |
| `image/Dockerfile`, base image tag | Upstream | Dependabot PR (may do nothing, see Open questions) |

References: `dependabot.yml` is class 4, owned by the template (UDF `:79`, `:98`, `:262`), rendered from the answers. Its entries:

- `github-actions` at `/`, for the stub pins (GHA `:53`).
- `nuget` at the dependency manifest's folder, new (Paket `:97`, `:119`, `:161`).
- `cargo` at `/`, from `rust-app`.
- `docker` at the Docker context, from `container` (UDF `:134`).
- `docker` or `devcontainers` at `/.devcontainer`, for the dev container reference (UDF `:94`). Covered under Dev environment.

Brownserve refs (`Brownserve-UK/*` actions, `Brownserve.*` packages) are grouped into one PR and excluded from the cooldown (GHA `:139`, Paket `:161`). Without that, a Tier 1 fix could take two 30-day cooldowns to arrive. Not verified (GHA V7 `:192`, Paket V2 `:189`).

No research doc distributes the `Cargo.toml` files, `Cargo.lock` or `image/Dockerfile`. `UpdateCargoVersion` moves into the task package unchanged (IBT `:38`, `:114`), so T3 carries over and keeps its ID.

- **Local edits to `dependabot.yml`:** the file is owned by the template (UDF `:79`), but Copier's 3-way merge keeps a maintainer's local `ignore` rule (UDF `:135`). Only matters on removal. Covered in Trace C.
- **Ecosystem labels:** `nuget` adds a third ecosystem with no Terraform label (see Open questions). Covered under GitHub settings.

**Dev environment**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `devcontainer.json` stub | Template | `copier copy` |
| Dev container reference (image tag or Feature versions) ⚠ A4 | Template (first pin); Upstream | `copier copy`; Dependabot PR |
| Dev container toolset (today's `.devcontainer/Dockerfile`) ⚠ A7 | Not settled | Dev container build |
| `extensions.json`, template entries | Template | `copier copy` |
| `extensions.json`, maintainer additions ⚠ A8 | Maintainer | Hand edit |
| `settings.json`, template settings (including cSpell) | Template | `copier copy` |
| `settings.json`, maintainer edits ⚠ A8 | Maintainer | Hand edit |
| `.editorconfig` | Template | `copier copy` |

References: the devcontainer files become class 1 plus a class 4 stub, through published images (Dependabot `docker`) or dev container Features (Dependabot `devcontainers`) (UDF `:94`, D4 `:283`). `.editorconfig` is class 4 (UDF `:98`). `extensions.json` and `settings.json` are class 5 (UDF `:99`). cSpell words are class 3 if `import` can reach a shared list, otherwise class 5 (UDF `:97`, V6 `:298`). `.editorconfig` sections follow the capabilities: Rust and TOML from `rust-app`, Dockerfile and shell from `container` (UDF `:134`, `:244`).

- **Manual sections:** `.editorconfig` loses its manual section marker; the 3-way merge carries a local rule instead (UDF `:245`). `bsdev`'s is empty, so it has no maintainer row.
- **Removal:** today's add-only merge leaves a removed capability's extensions and settings behind (see the Phase 1 Dev environment table). Capability conditionals should remove them instead. Covered in Trace C.
- **Repeated information:** Ubuntu focal moves into the published image, so its three copies go. The extension list is in both `extensions.json` and `devcontainer.json` today; the research doesn't say whether the stub still carries it.
- **Ecosystem labels:** the `/.devcontainer` entry adds another ecosystem with no Terraform label. Covered under GitHub settings.

**Repository hygiene**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.gitignore`, template sections | Template | `copier copy` |
| `.gitignore`, maintainer additions (`image/proto/node_modules/`) ⚠ A8 | Maintainer | Hand edit |
| `.markdownlint.json` ⚠ A9 | Template | `copier copy` |

References: `.gitignore` is class 5 (UDF `:99`). Its sections follow the capabilities: `target/` and `**/*.rs.bk` from `rust-app`, `.docker/` from `container` (UDF `:134`, `:244`). `.markdownlint.json` is class 3 if `extends` can reach a shared file without npm, otherwise class 4 (UDF `:96`, V6 `:298`).

- **Paket entries:** an unconditional template section, since every repo has the build. `paket.lock` and `paket-files/` go (Paket `:170`). The new `packages.lock.json` has to be committed, because Dependabot bumps it with the manifest (Paket `:97`); today's comment says the lock is ignored on purpose (`.gitignore:4`). `packages/` stays only if restore stays repo-local (Paket D4, `:179`). The restore project's `obj/` and `bin/` need ignoring (Paket V8, `:195`).
- **If V6 holds:** `.markdownlint.json` becomes an `extends` stub, still through `copier copy`, plus a shared file. No research doc says where the shared file lives or how it reaches the repo.
- **Manual sections:** `.gitignore` loses its manual section marker; the 3-way merge carries a local line instead (UDF `:245`).
- **Removal:** dropping a capability should drop its ignore lines. Covered in Trace C.

**Docs**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `README.md` | GitHub (auto-init), then Maintainer | Repo creation; Hand edit |
| `CHANGELOG.md`, header and placeholder ⚠ A10 | Template | `copier copy` (scaffold) |
| `CHANGELOG.md`, entries | Release history | Staged release |
| `LICENSE` | GitHub's licence list, chosen in Terraform | Repo creation |
| `CLAUDE.md` | Maintainer | Hand edit |
| `CONTRIBUTING.md`, baseline and capability sections | Template | `copier copy` |
| `CONTRIBUTING.md`, repo additions ⚠ A8 | Maintainer | Hand edit |
| `pull_request_template.md`, baseline and capability items | Template | `copier copy` |
| `pull_request_template.md`, repo additions ⚠ A8 | Maintainer | Hand edit |

References: CONTRIBUTING and the PR template are class 2 (org `.github` defaults) or class 4 (UDF `:95`, D3 `:282`). `CHANGELOG.md` is a class 6 scaffold through `_skip_if_exists` (UDF `:81`, `:102`, `:138`). Capability sections follow the capabilities (UDF `:134`, `:244`); a repo addition is carried by the 3-way merge (UDF `:245`), or the file is ejected (UDF `:246`).

- **Per-repo variation:** CONTRIBUTING and the PR template share a baseline, and repos (even with the same capabilities) add their own items (confirmed by the maintainer). That rules out class 2: GitHub only falls back to the org copy when the repo has none (UDF `:77`), and doesn't merge the two, so one extra item would cut the repo off from baseline updates. Today nothing carries a repo addition: both files are compared whole and replaced (`Compare-BrownserveRepository.ps1:1962-1974`, `:2019-2031`), with no manual section marker.
- **`container` gap:** neither file mentions `container` today (see the Phase 1 Docs table). No research doc says what a `container` section would hold, so the gap carries over until one is written.
- **Licence:** set with `license_template` on the repo's module call (maintainer's proposal). GitHub keeps the licence texts, so the template doesn't ship a `LICENSE` and `New-SPDXLicense` retires. It's create-only: whether changing it later forces the repo to be replaced, and which name the copyright line uses, are not verified.
- **README scaffold:** `auto_init` (`modules/github-brownserve_repo/repository.tf:9`) already writes `README.md`, so a Copier scaffold under `_skip_if_exists` would be skipped. This differs from UDF `:81`, `:102`. Not verified against a Brownserve repo.
- **Repeated information:** the Conventional Commits table stays in the template's CONTRIBUTING, while the title-to-label mapping moves to the shared workflows (GHA D7). Still two copies, now in two separately released sources. `CLAUDE.md` still restates facts the capabilities own (binary name, GHCR).

**Generator**

| Thing | Comes from | Gets there by |
| --- | --- | --- |
| `.copier-answers.yml`, answers (capabilities, plus any settings the template needs) | Maintainer | `copier copy` |
| `.copier-answers.yml`, template version (`_commit`) | Template | `copier copy` |
| Project config ⚠ A1 | Maintainer | Not settled: the same file as the answers, rendered from them, or a hand edit |

Retired: `.brownserve_repository_manifest` (UDF `:103`).

**Problems**

- **A1. How the project config gets written isn't settled.** It could be the answers file itself, rendered from it, or written by hand (UDF `:264`, `:285`). If it's written by hand, the capabilities and settings such as the Docker context would be stated in two files: Copier needs the Docker context to render `dependabot.yml` and the CI stub's path filter (UDF `:134`), and the build tasks read it from the project config (IBT `:142`).
- **A2. Nothing settles who writes the `Extends` list.** The project build script's `Extends` list names the capabilities (IBT `:147-155`), a third place they're stated after the answers file and the project config. If the template renders it, the maintainer's project-only tasks sit in a template-owned file. If the maintainer writes it, it can drift from the answers (removing `container` wouldn't touch it). It might instead be worked out at run time from the project config (IBT V4, `:231`), which could make the build script identical everywhere and shippable in the package (IBT `:162`, D6 `:220`).
- **A3. Nothing settles how packages get into the dependency manifest at set-up.** The template never holds versions, so even shared packages need `dotnet add package`. UDF suggests a Copier migration or task (`:256`); only a task fits at set-up, because migrations run when an update crosses a version (UDF `:136`). Not verified (UDF V4, `:296`); Paket D7 (`:182`) is still open. For `bsdev` every package is shared by all capabilities, so a capability bringing its own package comes up in later traces.
- **A4. Nothing settles where the template's pin comes from, or whether it ever moves.** Dependabot owns the pin (UDF `:262`), but the stub is rendered from the template, so the first pin has to come from it. Copier's 3-way merge keeps Dependabot's bump only if the template leaves that line alone (UDF V1, `:293`). If the template pins `ci` at `v1.0.0`, Dependabot bumps `bsdev` to `v1.2.0`, and the next template release moves its pin to `v1.1.0` so new repos start more current, `copier update` sees both sides change the same line and commits a conflict (UDF `:147`). The manifest versions had the same shape and were answered by the template never holding versions (UDF `:254`); the research has no equivalent for pins. The dev container stub's image or Feature reference has the same shape (see Dev environment).
- **A5. Publish targets have two proposed homes.** The project config holds publish targets (IBT `:142`), and dispatch inputs live in the stub (GHA `:85`). Today's `publish_to` is a per-run choice with a default (`release.yaml:5-10`). Nothing says whether the stub still offers that choice, or how its default relates to the config's list. Both follow the capabilities (`container` brings GHCR and DockerHub), so removing `container` would need both changed.
- **A6. Nothing creates or checks the files the capabilities expect the maintainer to write.** The shared tasks assume the root `Cargo.toml` has `[workspace.package]` with a `version` (`build_tasks.ps1:316-320`, or `StageRelease` fails), the binary in `cli/Cargo.toml` is named `BinaryName` (`:567-571`, or `Package` can't find it), and a Dockerfile sits in the Docker context (`:131`, `:184`, or `BuildImage` fails). The binary name and Docker context are also in the project config (IBT `:142`), with no route between the two. A new `rust-app` repo made with `cargo new` has no `[workspace.package]`, so it builds and tests fine until its first `StageRelease`. The research's scaffold class (class 6) lists only `LICENSE`, `CHANGELOG.md`, `README.md` and the Astro scaffold (UDF `:81`, `:102`).
- **A7. The dev container toolset has no settled source.** `bsdev` needs PowerShell (every repo, because the build runs in `pwsh`), Rust (`rust-app`) and Docker tooling (`container`, missing today, see the Phase 1 Dev environment table). A dev container uses one image, so an image per capability can't be combined, and an image per combination grows with every new mix. A base image plus one Feature per capability combines, but each Feature has to be built and published. Images or Features is still open (UDF D4, `:283`), and no research doc says which repo builds and publishes them, or with what workflow.
- **A8. Additions from the template and the repo to the same list can conflict.** When both append to the end of a list in a class 5 file, their edits touch the same or adjacent lines. In JSON, appending also adds a comma to the previous last line. If the maintainer adds `"bsdev"` after `"yzhang"` in the cSpell words (`settings.json:15`), and the next template release also adds a word at the end, both sides change `"yzhang"` to `"yzhang",` and `copier update` commits a conflict. UDF's "a cSpell word the template didn't touch is kept" (`:135`) holds only when the template's change is elsewhere in the list. The same applies to `extensions.json` and `.gitignore`. Not verified: this is how git-style 3-way merges treat adjacent edits, not tested with Copier. If V6 holds, cSpell words move to a shared list and drop out of this.
- **A9. Nothing keeps a file identical across repos once Copier merges.** Today `.markdownlint.json` is overwritten whole so that no repo drifts (`Compare-BrownserveRepository.ps1:1704-1748`). Copier's 3-way merge keeps any local edit the template didn't touch (UDF `:135`). That includes class 4 files, whose "overwrite is fine" (UDF `:79`) isn't how Copier updates them. As class 3, the local half exists to hold local rules (UDF `:78`, `:245`). Either way a repo could switch a rule back on and keep it on without ejecting, though ejecting is the research's visible route for divergence (UDF `:246`). The research doesn't say whether the "no local changes" rule should survive.
- **A10. Nothing ties the changelog scaffold to the parser that reads it.** Today the header and its `v0.0.0` placeholder come from `New-BrownserveChangelogHeader.ps1:7-20`, and `Read-BrownserveChangelog` detects that exact placeholder (`Read-BrownserveChangelog.ps1:203`). Both live in PSBuildTools and release together. As a scaffold, the placeholder moves into the template, while the parser stays in a Brownserve module the task package uses. If the parser's format changes, a repo set up from an older template release gets a placeholder the parser doesn't recognise, and its first staged release treats `v0.0.0` as a real release. It only matters before a repo's first release.

### Trace A: declare `rust-app` + `container`

A maintainer sets up a new repository and declares it's `rust-app` + `container`. Set-up is a Terraform change followed by `copier copy` (UDF `:266`). One line per chunk: the declaration, then each group in turn.

- **Declaration.** Reached: answers file, project config. Problems: A1. The workflow stubs' `capabilities` input (GHA `:108`) isn't a separate source: Copier renders the stubs from the answers (UDF `:89`, `:262`).
- **Build.** Reached: shared tasks and stock tests (through the task package), bootstrap, project build script, project tests, dependency manifest and lock file, `nuget.config`. Problems: A2, A3. Clears T4, and T2 for the tests (the template no longer writes the test file).
- **CI workflows.** Reached: shared workflow logic (through the stubs), stubs for `ci`, `pr-checks`, `stage-release`, `release` and template sync, and their pins. Problems: A4, A5. Narrows T1 to A4: a conflict only when the template moves its own pin, rather than every regeneration reverting it. Clears T2 for `publish_to`: the input becomes part of the template, and a hand edit in a stub is kept by the 3-way merge (UDF `:135`), so T2 is fully cleared.
- **Dependency tooling.** Reached: `dependabot.yml`, with `cargo` from `rust-app`, `docker` at the Docker context from `container`, plus `github-actions` and `nuget`, Brownserve refs grouped and excluded from cooldown. The `Cargo.toml` files, `Cargo.lock` and `image/Dockerfile` aren't reached: they stay with the maintainer. Problems: A6. Carries T3 over unchanged; the fix would now live in the task package. Completes the T4 clear with the `nuget` entry.
- **Dev environment.** Reached: `devcontainer.json` stub and its reference, `extensions.json`, `settings.json` and `.editorconfig`, with the Rust and Docker entries from the capabilities, plus a `dependabot.yml` entry at `/.devcontainer`. The toolset (today's `.devcontainer/Dockerfile`) isn't reached: its source isn't settled. Problems: A4 (widened), A7, A8. No T problems in this group.
- **Repository hygiene.** Reached: `.gitignore`, with `target/` and `**/*.rs.bk` from `rust-app`, `.docker/` from `container`, and its Paket entries replaced by the NuGet ones; `.markdownlint.json`. Problems: A8 (applies to `.gitignore`), A9. No T problems in this group.
- **Docs.** Reached: `CONTRIBUTING.md` and the PR template, with the Rust prerequisite and `cargo` items from `rust-app` and nothing from `container`; the `CHANGELOG.md` scaffold; `README.md` and `LICENSE` from repo creation. `CLAUDE.md` isn't reached: it stays with the maintainer. Problems: A8 (applies to both checklist files), A10. No T problems in this group.

## Phase 3: Decisions

Not started.

## Open questions

- **`removed` vs `removal` label.** `label-pr.yaml:88` applies `removed`, but Terraform defines `removal` (`modules/github-brownserve_repo/issues.tf:93`). Terraform's labels are authoritative (`issues.tf:2-3`). This isn't specific to `rust-app` or `container`, but it's two sources of the same information that disagree. The changelog groups entries by these labels, so the mismatch reaches `CHANGELOG.md` too.
- **Dependabot `docker` entry may do nothing.** `image/Dockerfile:8` uses `archlinux:latest` with no version or digest. Dependabot bumps versioned tags or digests, so this entry (`dependabot.yml:18-23`) probably never opens a PR. Not verified.
- **Dependabot ecosystem labels.** Terraform has `dependencies` and `github_actions`, but no label for `cargo` or `docker` (`issues.tf:56-97`). Because the label set is authoritative, any label Dependabot creates would be deleted on the next apply. Not verified.
- **Org `CODE_OF_CONDUCT.md` not verified.** `bsdev`'s PR template links to it in the `.github` repo (`repos.tf:123`), which isn't checked out locally.
