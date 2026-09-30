# 2026-09-30 - Invoke-Build Tasks

First stab at Phase 2 of [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).
The goal is to understand the overall shape well enough to start drawing up contracts. Nothing here is decided.
Companion to [2026-09-30 - GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md), which this leans on for the Phase 1 / Phase 2 boundary.

## Where we are today

### Inventory

Every repo gets three generated build files. All three are fully owned by `Initialize-` / `Update-BrownserveRepository`.

| File | Templates | Size | Notes |
| --- | --- | --- | --- |
| `.build/tasks/build_tasks.ps1` | 5 (`psmodule`, `rustapp`, `bsdev`, `webapp`, `skillsrepo`) | 514 to 1365 lines | The Invoke-Build tasks. The subject of this phase. |
| `.build/build.ps1` | 5 | 160 to 229 lines | Almost entirely parameter plumbing: declares params, runs `_init.ps1`, splats them into `Invoke-Build`. |
| `.build/_init.ps1` | 1, with placeholders | 189 lines | Globals, ephemeral dirs, paket restore, module import. Custom section is preserved on update. |

Bundled Invoke-Build is 5.14.23.

### Drift in the live repos

None. `build_tasks.ps1` in PSCommon, PSSourceControl, PSBuildTools and `bsdev` is byte-identical to its template after placeholder substitution (ignoring CRLF). Same for `build.ps1` apart from `###OWNER###`.

So unlike Phase 1 the problem is not drift, it is **propagation and divergence between templates**. Nobody customises the tasks locally, which makes them an easy candidate to pull out of the repos entirely.

### Duplication across templates

| Task group | Present in | How the copies differ |
| --- | --- | --- |
| `CheckStagingParameters`, `SetStagingVariables`, `SetReleaseVariables` | All 5 | Nothing meaningful. |
| `GetReleaseHistory`, `SetVersion` | All 5 | `psmodule` uses `Update-Version` + `Format-NuGetPackageVersion` and supports pre-releases. The other four hand-roll a semver `switch` with no pre-release support. |
| `CreateChangelogEntry`, `UpdateChangelog` | All 5 | Nothing meaningful. |
| `CreateStagingBranch`, `CommitTrackedChanges`, `CreatePullRequest` | All 5 | Only which extra files get committed (`Cargo.toml`/`Cargo.lock`, module docs). |
| `Tests` (Pester) | All 5 | `webapp` sets a global image name first. |
| GitHub release publishing | All 5 | `psmodule` publishes directly. The other four go draft, upload assets, un-draft. |
| `CheckPublishingParameters` | All 5 | Per-target secret checks, same pattern each time. |
| Rust build / test / package / `UpdateCargoVersion` | `rustapp`, `bsdev` | Identical. `bsdev` is literally `rustapp` + container. |
| Docker build / push to GHCR and DockerHub | `bsdev`, `webapp` | Build context differs (`image/` vs repo root). |
| PowerShell module build, docs, help, NuGet, PSGallery | `psmodule` | Only one copy, but it is ~60% of all task code. |
| `CheckForUncommittedChanges` | `psmodule` only | Other types never check. |
| `DryRun` | 4 of 5 | `webapp` has none. |

Roughly, one project type is a **combination of capabilities**, and each template is a hand-merged copy of those capabilities. That lines up with the brief's plan to drop explicit project types.

### Other things worth knowing

- Most task bodies are already thin wrappers around cmdlets. What is actually duplicated is the **glue**: parameter validation, the task dependency graph, and the `$script:` state passed between tasks (`$script:Changelog`, `$script:NewVersion`, `$script:TrackedFiles`, `$script:PrefixedVersion`, ...). That glue is where the copies have drifted apart.
- Entry-point task names are shared but their meanings are not. `Build` means "manifest only" for `psmodule`, `cargo build` for Rust, "package skills + build docs" for skills. `BuildTestAndCheck` is the one consistent name, and it is a Terraform required check.
- Tasks depend on `_init.ps1` globals (`$Global:BrownserveRepo*`) and on cmdlets from all three PSTools modules, so any shared task code is coupled to module versions.
- `ModuleInfo.json` declares `RequiredModules`, but nothing uses it. The generated manifest has no `RequiredModules` and the nuspec has `<dependencies />`. Load order is enforced only by `_init.ps1`.
- The `UseWorkingCopy` option exists in the generator but none of the PSTools repos use it, so each PSTools module is released using the previous release of the PSTools modules.
- Secrets reach the tasks as `build.ps1` parameters, which the workflows build from `${{ secrets.* }}` and inputs.
- `packages/` in this repo contains a stale `Brownserve.PSBuildTasks` 0.2.0 that isn't in `paket.dependencies`. It looks like a leftover from the previous attempt, so I haven't opened it. Worth checking whether that name is already registered on nuget.org before choosing a name (see [D8](#decisions-needed)).

### What Invoke-Build gives us

Reading the bundled 5.14.23 source, these matter for this phase:

| Feature | What it does | Why it matters |
| --- | --- | --- |
| `Extends` parameter | A build script declares `[ValidateScript({ '<base>.build.ps1' })] $Extends`. Invoke-Build loads the base script's tasks **and its parameters**, recursively. `'Prefix::path'` namespaces the base's tasks. | Native mechanism for a shared task library. No dot-sourcing tricks. |
| Task redefinition | Defining a task that already exists replaces it and prints `Redefined task 'X'`. | A project can override a shared task when it genuinely needs to. |
| `-Before` / `-After` on `task` | Injects a task into another task's graph without editing it. | Lets a capability hook into shared flows (e.g. `UpdateCargoVersion -Before CommitTrackedChanges`). |
| `-If` on `task` | Conditional tasks. | Publish targets, optional capabilities. |
| `property` (`Get-BuildProperty`) | Reads a variable, falls back to an environment variable. | Secrets and CI inputs can come from env vars with no plumbing. |
| `Invoke-Build ??` | Returns the task graph without running it. | Graph shape can be unit tested. |

## What the problem really is

The brief frames this as duplication. Splitting it:

1. **Logic duplication.** Mostly solved already by cmdlets. What remains is glue.
2. **Graph duplication.** Every template re-declares the same dependency graph, slightly differently.
3. **Propagation.** Changing one task means regenerating every repo. The copy that is forgotten is found at release time.
4. **Divergence.** Because each copy evolved alone, the same concept behaves differently per type (pre-releases, draft releases, dry runs, uncommitted change checks).

A shared package fixes 2 and 3 directly. It only fixes 4 if we **deliberately unify** behaviour while moving, rather than copying five variants into one package.

## Options for where the tasks live

| Option | Summary | Verdict |
| --- | --- | --- |
| A. Keep templates, improve the generator | Status quo with better tooling. | Doesn't fix propagation. Rejected. |
| B. Separate task package | A content-only NuGet package of task scripts, consumed via `Extends`. Declares nuspec dependencies on the module versions it needs. | **Leaning this way.** |
| C. Ship tasks inside `Brownserve.PSBuildTools` | Task scripts live in the module, exposed by a path cmdlet. | Guaranteed task/cmdlet compatibility, but tasks can only ship on the module's cadence and the module's scope grows again. Viable fallback. |
| D. Move all glue into cmdlets | e.g. `Invoke-BrownserveStageRelease`. Tasks become one-liners. | Good for testability, but the graph is still duplicated per repo. Complements B rather than replacing it. |
| E. Drop Invoke-Build | Let Phase 1 workflows orchestrate everything. | Loses local parity with CI and ties logic to GitHub Actions. Rejected. Phase 1 workflows orchestrate **across jobs**, Invoke-Build orchestrates **within a job**. |

B over C mainly because the nuspec can declare `Brownserve.PSBuildTools >= x < y`, which gives independent release cadence and a compatibility guarantee. C's only real advantage is one fewer repo.

## Proposed shape

```text
Layer 1: cmdlets                Brownserve.PSCommon / PSSourceControl / PSBuildTools
         (logic, unit tested)
              ^ nuspec dependency ranges
Layer 2: task library           Brownserve.<name> NuGet package
         (graph + glue, one file per capability)
              ^ Extends
Layer 3: project build script   <project>/.build/project.build.ps1 + config
         (capabilities, settings, project-only tasks)
```

### Layer 2: task library

One base script per capability. Each can extend `core`.

| Base script | Tasks | Used by today |
| --- | --- | --- |
| `core` | Release history, versioning (one implementation, pre-releases everywhere), changelog, staging branch / commit / PR, uncommitted changes check, Pester, shared state | All |
| `github-release` | Existing release check, draft, upload everything in the assets dir, un-draft | All |
| `powershell-module` | Copy, manifest, import, PlatyPS docs, MAML help, NuGet pack, NuGet / PSGallery / custom feed publish | PSTools |
| `rust` | Cargo build / test, `UpdateCargoVersion`, per-target packaging | `rustapp`, `bsdev` |
| `container` | Docker build, GHCR / DockerHub push | `bsdev`, `webapp` |
| `skills` | Skills packaging | `ai-skills` |
| `docs-astro`, `docs-mkdocs` | Docs site build | skills, others |

The capability names should be the same vocabulary as Phase 1's capability inputs (C7 there).

### Entry points

`core` defines stable entry-point tasks. Capabilities hook into them with `-Before` / `-After` rather than redefining them. Illustrative only:

| Entry point | Meaning | Capability hooks (examples) |
| --- | --- | --- |
| `Build` | Produce the thing | module manifest, `cargo build`, `docker build` |
| `Test` | Build + all tests | Pester, `cargo test` |
| `Check` | `Test` + hygiene. What CI runs on PRs. | Uncommitted changes, docs up to date |
| `StageRelease` | Bump version, update changelog, commit tracked files, open PR | `UpdateCargoVersion`, module docs help version |
| `Package` | Produce release assets into the assets dir | nupkg, tarballs per target, skills zip |
| `Release` | Publish assets (draft-first) | PSGallery, NuGet, GHCR, DockerHub |
| `DryRun` | `Release` minus anything that publishes | Everything |

`BuildTestAndCheck` stays as an alias for `Check` until Terraform's required check names move (Phase 1 C5).

### Layer 3: the project

What stays in each repo:

- A small build script that `Extends` the capabilities it needs and holds project-only tasks.
- A declarative config file with capabilities and per-capability settings (module name/GUID, binary name, image name, docs path, publish targets). This replaces `ModuleInfo.json` and the per-type parameter lists.
- Tests.

Illustrative only:

```powershell
param(
    [ValidateScript({
        'core::../packages/Brownserve.BuildTasks/tasks/core.build.ps1'
        'psmod::../packages/Brownserve.BuildTasks/tasks/powershell-module.build.ps1'
        'gh::../packages/Brownserve.BuildTasks/tasks/github-release.build.ps1'
    })]
    $Extends
)

task CheckSomethingOnlyThisRepoCares -Before core::Check {
    ...
}
```

If config drives everything, `build.ps1` becomes identical in every repo and could itself be shipped rather than generated (see [D6](#decisions-needed)).

### Shared state

Today 10 to 15 loose `$script:` variables form an implicit contract between tasks. With several base scripts this needs to be explicit: one well-known state object (version, previous version, release notes, tracked files, assets, PR link) that capabilities read and add to. This is the internal contract between capabilities.

### Inputs and outputs

- **Inputs:** secrets and runtime values (branch, release type, publish targets, target triple) come from environment variables via `property`, not `build.ps1` parameters. Workflows set `env:`, locals set nothing or use a `.env`-style helper. This also removes the script injection path flagged in Phase 1.
- **Outputs:** release assets always land in one known directory (e.g. `.tmp/output/assets`), which is what Phase 1 workflows upload and download between jobs. A machine-readable summary (e.g. `.tmp/output/build-summary.json` with version, PR link, asset list) lets workflows and notifications stop scraping logs or re-running `_init.ps1`.

## Bootstrapping and self-hosting

- `Extends` is resolved when Invoke-Build binds parameters, before any task runs. The package has to be restored first, which `build.ps1` already guarantees by running `_init.ps1`.
- The task package's own repo, and the three PSTools repos, will build using a **released** version of the task package. That is the same rule as Phase 1 (a release never depends on the version being released) and it avoids the package breaking its own release.
- Developing tasks needs a working copy override (generalising today's `UseWorkingCopy`), e.g. an env var pointing `Extends` at a local checkout. The `ValidateScript` block is executed, so this is possible.
- There's a loose cycle: the task package depends on the modules, and the modules build with the task package. Pinning to released versions breaks it, but a broken task release must never stop us releasing a module fix.

## Versioning and propagation

- Semver on the package. Breaking changes include: removing or renaming entry points, changing config schema, env var names, asset layout or summary format, and raising the minimum module version range.
- How fast a change reaches a project depends entirely on the paket research question. Today nothing is locked, so every build takes the latest (instant, non-deterministic). If we lock, we need an update mechanism Dependabot understands. This phase shouldn't decide that, but it shouldn't assume either.
- A Phase 1 Tier 2 workflow and the task package will sometimes need to change together (e.g. new entry point, new asset). The entry-point contract should make this rare.

## Testing

- **Fixture projects**, shared with Phase 1 Tier 2: a tiny PowerShell module, a tiny Rust crate, a tiny container, a skills dir. CI runs every entry point against every fixture.
- **Graph tests:** `Invoke-Build ??` per capability combination, asserting the expected tasks and order. Cheap and catches most wiring mistakes.
- **Side effects:** GitHub calls are the risky bit. Either mock at the cmdlet level (already the pattern with `Invoke-NativeCommand`) or run against a dedicated sandbox repo.
- **`DryRun` for every capability**, so a canary repo can exercise a release without publishing.

## Contracts to draw up next

| # | Contract | Covers |
| --- | --- | --- |
| P1 | Entry points | Names, meaning, what each capability contributes. Same thing as Phase 1 C4 from the other side. |
| P2 | Project config | Schema, capability names (Phase 1 C7), per-capability settings, where it lives. |
| P3 | Inputs | Env var / property names for secrets and runtime values. |
| P4 | Outputs | Asset dir layout, build summary format, exit behaviour. |
| P5 | Environment | Which `_init.ps1` globals are guaranteed, and replacing the repo-name-from-folder assumption (Phase 1 checkout path issue). |
| P6 | Extension points | Shared state object, which tasks capabilities may hook with `-Before` / `-After`, when overriding is allowed. |
| P7 | Package / module compatibility | Nuspec dependency ranges, and module manifests actually declaring `RequiredModules`. |

## Rollout sketch

1. Create the package with `core` and `github-release`, unifying the divergent behaviour on the way in.
2. Add `powershell-module` and move one PSTools repo (probably PSBuildTools, as it exercises the most). Behaviour should be identical apart from the deliberate unifications.
3. Add `rust` and `container`, move `bsdev`.
4. `skills`, docs, `webapp`.
5. `Update-BrownserveRepository` stops generating `build_tasks.ps1` (and possibly `build.ps1`) for migrated repos.

## Decisions needed

- **D1.** Separate task package (B) or tasks inside `Brownserve.PSBuildTools` (C)? (Leaning B.)
- **D2.** `Extends` or plain dot-sourcing? (Leaning `Extends`, pending V1 to V4.)
- **D3.** Declarative project config, and which format (JSON, PSD1, YAML)?
- **D4.** Secrets and runtime inputs via env vars instead of parameters?
- **D5.** Unify behaviour everywhere: pre-release support, draft-first releases, uncommitted change checks, `DryRun`? Any of these that should stay type-specific?
- **D6.** Does `build.ps1` become generic and shipped too? What about `_init.ps1`? (Overlaps the "how do we update things" question.)
- **D7.** Entry point names: keep today's (`BuildTestAndCheck` etc.) or move to lifecycle names with aliases?
- **D8.** Package name, and what to do about the existing `Brownserve.PSBuildTasks` if it's on nuget.org.

## Things to verify

Believed true from reading the Invoke-Build source, not yet confirmed with a spike.

- **V1.** Multiple `Extends` entries, and a diamond (two capabilities both extending `core`) loads `core` once or harmlessly twice.
- **V2.** Tasks from a base script run with `$BuildRoot` set to the base script's directory (i.e. inside `packages/`). `exec { cargo ... }` would run there. Confirm a base can safely set `$BuildRoot` to the repo root, or that we always use absolute paths.
- **V3.** `$script:` state is shared across all extended scripts.
- **V4.** The `Extends` `ValidateScript` can compute paths dynamically (package path, working copy override).
- **V5.** `-Before` / `-After` work across scripts and prefixes (`task X -Before core::Check`).
- **V6.** Parameters contributed by bases show up correctly when `build.ps1` splats into `Invoke-Build`.
- **V7.** Paket resolves transitive nuspec dependencies the way we expect when nothing is locked.
- **V8.** `Invoke-Build ?` shows synopsis help for tasks that come from base scripts.

## Out of scope but noticed

- `CheckPreviousReleases` in `psmodule` checks `'CustomFeeds' -in $PublishTo`, but the valid value is `CustomNugetFeeds`, so the custom feed duplicate check never runs.
- Module manifests never declare `RequiredModules` and nuspecs never declare dependencies, even though `ModuleInfo.json` lists them.
- The `psmodule` custom feed branch logs `Azure DevOps not targeted` when skipping.
