# 2026-09-30 - Updating Distributed Files

Research for the "How do we solve updating things" question in [2026-09-29 - Refactor](../prompts/2026-09-29%20-%20Refactor.md).
Nothing here is decided. It leans on [GitHub Actions](./2026-09-30%20-%20GitHub%20Actions.md) (C6), [Invoke-Build Tasks](./2026-09-30%20-%20Invoke-Build%20Tasks.md) (D6) and [Paket](./2026-09-30%20-%20Paket.md) (D7), which all deferred "who owns this file" to here.

## Where we are today

### How an update works

`Update-BrownserveRepository` reads `.brownserve_repository_manifest` for the project type, then `Compare-BrownserveRepository` (2476 lines) renders every file for that type into memory and diffs it against disk. Anything missing or different is written to a `brownserve_repo_update_<yyyyMMdd>` branch. The source material is 44 templates under `Module/Private/Build/templates` plus 8 JSON config files, all shipped inside `Brownserve.PSBuildTools`.

What it doesn't do:

- **Tell anyone an update exists.** Someone has to remember to run it, in every repo, with a recent PSBuildTools loaded.
- **Open a PR.** It leaves a local branch.
- **Record a version.** `ManifestVersion` is hardcoded to `1.0.0`. There is no way to know which templates a repo was last updated from.
- **Remove files.** It only creates and overwrites. A file dropped from a type stays in every existing repo forever.
- **Tell a template change from a local edit.** Its own comments say so. Every difference is treated as "template wins".

### Inventory by current behaviour

A PowerShell module repo gets 29 generated files. They are handled four different ways:

| Behaviour | Files |
| --- | --- |
| Overwrite whole file | manifest, `nuget.config`, `.markdownlint.json`, all 4 workflows, `CONTRIBUTING.md`, PR template, `build.ps1`, `build_tasks.ps1`, Pester tests, install scripts, `mkdocs.yml`, `requirements.txt`, `pages/index.md`, `.pages`, `dependabot.yml`, `devcontainer.json`, `Dockerfile`, `ModuleInfo.json` |
| Overwrite, keep a marked section | `_init.ps1` (user steps), `.gitignore` (manual ignores), `paket.dependencies` (manual deps), `.editorconfig` (manual sections) |
| Merge | `.vscode/settings.json` (deep merge, repo wins unless `-Force`), `.vscode/extensions.json` (union) |
| Create once | `CHANGELOG.md`, `LICENSE`, `.config/dotnet-tools.json`, Astro scaffold |

### Drift in the live repos

Comparing PSCommon, PSSourceControl and `bsdev` against PSBuildTools (ignoring CRLF):

- Within the PSTools repos almost everything is identical apart from template substitutions (module name in `mkdocs.yml`, `Help.Tests.ps1`, PR template).
- Genuine local edits are small and live exactly where the merge logic allows them: extra cSpell words in `.vscode/settings.json`, an extra `.gitignore` line.
- `bsdev` differs everywhere, but that is the type difference, not drift.
- Workflows are the exception (Dependabot pin bumps, a `bsdev` hand edit), covered in the Phase 1 research.

So the real problem isn't drift. It's that nothing tells us an update exists, and the thing that applies updates can't tell our change from theirs.

## What the problem really is

"Updating things" is really six problems. Today's tool half-solves one of them.

| # | Problem | Today |
| --- | --- | --- |
| U1 | **Trigger:** knowing a new version exists | Memory |
| U2 | **Delivery:** a reviewable PR, with CI, in every affected repo | Local branch, by hand |
| U3 | **Merge:** applying our change without destroying theirs (including Dependabot's) | Marked sections for four files, overwrite for the rest |
| U4 | **Variation:** which files apply to which repo, and with what content | Hardcoded `switch` on project type |
| U5 | **Removal:** dropping a file from repos that no longer need it | Not possible |
| U6 | **Visibility:** which version each repo is on | Not possible |

## What we need

| # | Requirement | Source |
| --- | --- | --- |
| R1 | Updates arrive as a PR without anyone remembering to look | Brief |
| R2 | One central, versioned source of truth for shared content | Brief |
| R3 | No custom bot. A GitHub Action is fine. Free, no self-hosted infra. | Brief |
| R4 | Per-repo variation, including a file being dropped for some kinds of repo, and content diverging over time | Brief |
| R5 | Local changes and Dependabot changes survive an update | Phase 1 problem 1 |
| R6 | Deletions propagate | U5 |
| R7 | Each repo records the version it's on | U6 |
| R8 | Controlled rollout: we pick when and where it lands (canary first) | Phase 1 / 2 rollout sketches |
| R9 | Works with signed-commit branch protection, and with private free-tier repos (no protection, no org secrets) | Terraform |
| R10 | Doesn't depend on project types (capabilities instead) | Brief |

## Principle: shrink the surface first

The cheapest file to update is one that doesn't exist in the repo. Before picking a sync mechanism, every file should be pushed as far up this list as it will go:

| Class | Meaning | Update mechanism | Example |
| --- | --- | --- | --- |
| 1. **Referenced** | The repo points at a versioned thing | Dependabot | A reusable workflow pin, a NuGet package, a container image tag |
| 2. **Inherited** | GitHub or a tool falls back to a central copy when the repo has none | Nothing, it's live | Org `.github` community health files |
| 3. **Extended** | A small local file that `extends` / `import`s a central one | Class 1 for the central part | `Extends` in Invoke-Build, `extends` in markdownlint |
| 4. **Owned** | Must be a real file, and we own all of it | Sync mechanism, overwrite is fine | `.editorconfig`, workflow stubs, `dependabot.yml` |
| 5. **Shared** | Must be a real file, and both we and the repo (or Dependabot) write to it | Sync mechanism, must merge | `.gitignore`, `.vscode/settings.json`, dependency manifest |
| 6. **Scaffold** | Created once, then belongs to the repo | Onboarding only | `LICENSE`, `CHANGELOG.md`, `README.md` |

Classes 1 to 3 need no new machinery beyond what the other research already proposes. Only 4 and 5 need a sync mechanism, and 6 only matters at onboarding.

### Where each current file could land

| Current file | Proposed class | How |
| --- | --- | --- |
| Workflows (4) | 1, plus a class 4 stub | Phase 1 Tier 2 reusable workflows. The stub remains an owned file. |
| `build_tasks.ps1` | 1 | Phase 2 task package via `Extends`. |
| `build.ps1`, `_init.ps1` | 1, plus a tiny class 4 bootstrap | Ship in the task package (Phase 2 D6). What stays is a few lines that restore dependencies and call into the package. |
| `Help.Tests.ps1` and other stock Pester tests | 1 | Ship in the task package as shared tests, driven by project config. |
| `paket.dependencies`, `dotnet-tools.json` | 5, versions owned by Dependabot | Paket option C. See [the manifest problem](#the-dependency-manifest). |
| `devcontainer.json`, `Dockerfile` | 1, plus a class 4 stub | Publish Brownserve dev container images to GHCR (`FROM ghcr.io/brownserve-uk/devcontainer-pwsh:1.2.3`, Dependabot `docker`), and/or dev container Features (Dependabot `devcontainers` ecosystem). |
| `CONTRIBUTING.md`, PR template | 2 | Org `.github` repo defaults (it's already public). Only works if we accept one generic version per org. Per-capability variants would have to stay as class 4. |
| `.markdownlint.json` | 3 or 4 | `extends` if it can reach a shared file without npm (V6), otherwise owned. |
| cSpell settings | 3 or 5 | cSpell `import` if it can reach a shared file (V6), with local words staying in the repo. |
| `.editorconfig`, `nuget.config`, `dependabot.yml` | 4 | No include mechanism exists for any of them. |
| `.gitignore`, `.vscode/settings.json`, `extensions.json` | 5 | No include mechanism. Repos genuinely add to them. |
| `mkdocs.yml`, `requirements.txt`, docs index | 4 / 6 | Config owned, landing page scaffold. Overwriting `pages/index.md` today looks wrong. |
| Install scripts | 4 | Or class 1, if moved into a release asset or a shared URL. |
| `CHANGELOG.md`, `LICENSE`, Astro scaffold | 6 | Unchanged. |
| `ModuleInfo.json`, `.brownserve_repository_manifest` | Replaced | Merged into the Phase 2 project config (P2), which also records the capabilities and the template version (R7, R10). |

If all of that lands, what's left for a sync mechanism is roughly: workflow stubs, the build bootstrap, `dependabot.yml`, `.editorconfig`, `.gitignore`, VS Code settings, dev container stubs, `nuget.config`, lint config. Around 10 small files, mostly class 4, instead of 29.

## Options for syncing what's left

### A. Automate the generator

Keep `Update-BrownserveRepository`, but run it from a scheduled workflow in each repo and open a PR with the result.

Good:

- Smallest change. Keeps the investment in `Compare-BrownserveRepository`.

Bad:

- The template version is the PSBuildTools version, so shared config can only ship on the module's release cadence, and a module bug blocks config updates.
- Still "template wins" (fails R5), still no deletions (R6), still types (R10). Fixing those means writing a 3-way merge ourselves.
- 2.5k lines of bespoke merge code for ~10 files is a lot to own.

Verdict: fallback only.

### B. Copier

[Copier](https://copier.readthedocs.io/) renders a project from a git-tagged template repo and writes `.copier-answers.yml` recording the answers **and the template commit**. `copier update` does a real 3-way merge: it regenerates the old version with the recorded answers, diffs that against the repo to extract local changes, renders the new version, then reapplies the local diff. Conflicts land as inline markers (or `.rej` files).

How it maps to the requirements:

| Need | Copier feature |
| --- | --- |
| R2 versioned source | Template repo with semver tags, versioned as a whole (same rule as Phase 1 Tier 2) |
| R4 variation | Answers (e.g. `capabilities: [powershell-module, container]`) drive Jinja conditionals in file content and file names. `_exclude` is templatable, so a capability can drop whole groups of files. |
| R5 local changes survive | 3-way merge. A cSpell word or a Dependabot bump the template didn't touch is kept. |
| R6 deletions | A file excluded in the new version is removed. Anything fiddlier goes in `_migrations`, which are gated on the version being crossed. |
| R7 visibility | `_commit` in the answers file. Searchable across the org. |
| Class 6 scaffold | `_skip_if_exists` |
| Layering | Multiple templates can be applied to one repo with separate answers files (`-a .copier-answers.ci.yml`), so capabilities could be separate templates if we wanted. |

The update itself runs in a workflow: `copier update --defaults`, then open a PR with the Brownserve CI App token (already installed on the PSTools repos, `bsdev`, `actions` and `PSBuildTasks`). That fits R1 and R3.

Gotchas:

- **Python.** Copier is a Python tool (`uvx copier` / `pipx`). Fine on runners and in dev containers, but it's a new runtime in the chain.
- **Jinja versus `${{ }}`.** Workflow stubs are full of GitHub expressions. We'd set custom delimiters with `_envops` (e.g. `[[ ]]`) for the whole template rather than escaping everywhere.
- **Conflicts get committed.** The update PR can contain conflict markers. CI must fail on them (a simple grep check), and someone resolves them in the PR.
- **Adoption.** Existing repos weren't made by Copier. Each needs a one-off `copier copy` over the top, a reviewed diff, and a commit of the answers file. After that, updates work normally.
- **Trust.** Migrations and tasks need `--trust`. Fine for our own template, but it means the update workflow runs template code.
- **Clean tree required.** Fine in CI, and a useful guard locally.

Verdict: **leaning this way** for classes 4 and 5.

### C. Cruft / Cookiecutter

Same idea as Copier, built on Cookiecutter. Uses patches and `.rej` files, has no migrations, no multi-template layering. Copier does everything Cruft does, so there's no reason to prefer it.

Verdict: rejected in favour of B.

### D. Central push sync

A workflow in a central repo pushes files to every consumer on release, e.g. `repo-file-sync-action` (the original `BetaHuhn` one, or the `step-security` fork, which bills itself as the maintained, security-hardened one). One config file maps files to repos, with templating and optional orphan deletion.

Good:

- Instant, and the rollout list is visible in one place.

Bad:

- **Overwrites.** No merge, so it recreates the exact Phase 1 problem: Dependabot bumps a pin in a stub, the next sync reverts it. Fails R5 outright for anything class 5, and for stubs.
- The central repo has to know every repo and its variables, which duplicates Terraform.
- Needs a token with write on every repo.

Verdict: rejected. Would only be safe for files nothing else ever edits.

### E. Terraform `github_repository_file`

Terraform already knows every repo, so it could manage file contents with `templatefile()`.

Bad:

- Commits straight to a branch. No PR, no CI before the change lands, and it fights branch protection (required checks, `enforce_admins`).
- Plans become noisy with content churn, and apply is a manual step in a private repo.
- Mixes repo settings with repo content, which the brief is trying to untangle.

Verdict: rejected for content. Terraform stays the owner of settings, secrets and the consumer list.

### F. Git submodules

Dependabot supports the `gitsubmodule` ecosystem. But GitHub won't read workflows, `dependabot.yml`, `.editorconfig` or `.gitignore` from a submodule, and Dependabot tracks branch heads (semver tag awareness is only just landing). Only helps for files consumed by path, and those are better served by the Phase 2 package.

Verdict: rejected.

### G. Dependabot as the doorbell (hybrid with B)

Dependabot can't bump a Copier template. But it can bump a reusable workflow pin. So:

1. Each repo has a stub `template-sync.yaml` calling `Brownserve-UK/<template repo>/.github/workflows/sync.yaml@<sha> # v1.4.0`.
2. Dependabot bumps that pin, grouped with the other `Brownserve-UK/*` bumps, with release notes.
3. On that Dependabot PR, the sync workflow (now at the new ref) runs `copier update --vcs-ref v1.4.0` and pushes the result to the same branch.

One PR with the pin bump and the file changes, triggered and described by Dependabot. No schedule of our own.

Gotchas:

- Dependabot-triggered `pull_request` runs get Dependabot secrets only, and a read-only `GITHUB_TOKEN` unless the workflow's `permissions:` raises it.
- Commits pushed with `GITHUB_TOKEN` don't trigger CI, so required checks never run on the final commit. We'd need the App key as a Dependabot secret and push with that.
- Dependabot stops rebasing a branch once someone else has committed to it.
- The reusable workflow needs to know its own ref to pass `--vcs-ref` (same open question as Phase 1 V5).

Verdict: promising, but fiddly. Worth a spike after B works with a plain trigger.

### Comparison

| | A. Generator | B. Copier | D. Push sync | E. Terraform | G. B + Dependabot |
| --- | --- | --- | --- | --- | --- |
| Trigger (U1) | Our schedule | Our schedule / dispatch | Central release | `apply` | Dependabot |
| PR with CI (U2) | Yes | Yes | Yes | No | Yes |
| Keeps local and Dependabot edits (U3) | 4 files only | Yes, 3-way | No | No | Yes, 3-way |
| Variation (U4) | Types | Answers | Central config | HCL | Answers |
| Deletions (U5) | No | Yes | Optional | Yes | Yes |
| Version recorded (U6) | No | Yes | No | In state | Yes |
| Custom code we own | ~2.5k lines | Template + small workflow | Config | HCL | Template + workflow |
| New tooling | None | Python | None | None | Python |

## Triggering and rollout

Whichever mechanism, the trigger should be two layers:

- **Push notification:** releasing the template repo fires `repository_dispatch` at consumer repos using the App token. Each consumer runs its own update and opens its own PR. This keeps the "pull" model (each repo owns its merge) while getting "push" latency. The consumer list comes from the App installation list, which Terraform already manages.
- **Schedule as a backstop:** weekly, in case a dispatch is missed or a repo was added later.

Rollout rings (R8) fall out naturally: dispatch to a canary repo first, then everyone. Or record a `channel` answer (`canary` / `stable`) and only dispatch stable repos once canary has merged. Repos can also stay pinned: if nobody merges the PR, nothing changes, and `_commit` shows they're behind.

The update workflow itself should be a Phase 1 Tier 2 reusable workflow, so the stub in each repo is a few lines and its pin is bumped by Dependabot like everything else.

## Variation and divergence over time

The brief's "maybe we drop it from certain kinds of repos, then later the content differs from one repo to the next" is really four cases, and each has a different answer:

| Case | Answer |
| --- | --- |
| A file applies to some repos and not others | Conditional on capabilities in the answers. Dropping a capability deletes its files on the next update. |
| Content differs by capability | Jinja conditionals in the template. Keep them coarse, per capability, not per repo. |
| One repo needs a small local addition | Let the 3-way merge carry it. For class 3 files, put it in the local half. |
| One repo diverges for good | **Eject:** an `eject` answer (list of paths) feeds `_exclude`, so the template stops touching that file and it becomes class 6 for that repo. Explicit and visible, rather than silent drift. |

The rule of thumb: variation lives in answers, never in "this repo's copy happens to be different".

## The dependency manifest

Paket D7 asks who owns the dependency manifest once Dependabot bumps it. It's the hardest class 5 file, because two automated writers touch the same lines.

- If the template contains versions, every template release fights Dependabot's bumps (a 3-way conflict whenever both moved the same line).
- So the template should **never contain versions**. It scaffolds the manifest (class 6), and Dependabot owns versions from then on.
- A capability that needs a new package (e.g. `powershell-module` needing `NuGet.CommandLine`) adds it via a Copier migration or task that runs `dotnet add package`, which picks the current version. Removing a capability removes its packages the same way.

This needs V4 to confirm it behaves.

## How this touches the other research

- **Phase 1 (C3, C6):** workflow stubs and `dependabot.yml` are class 4 files owned by the template. The stub contract should say the template owns everything in a stub except the pin, which Dependabot owns. The 3-way merge makes that work.
- **Phase 2 (D6, P2, P5):** the more of `build.ps1` / `_init.ps1` we ship in the package, the less the template has to carry. The project config and the Copier answers file overlap heavily. They could be one file, or the answers could render the config.
- **Paket (D7):** answered above, pending V4.
- **Capabilities (Phase 1 C7):** the answers file is where a repo declares its capabilities. That makes it the single place the vocabulary is consumed from.
- **The generator:** `Initialize-` / `Update-BrownserveRepository`, `Compare-BrownserveRepository`, the templates and the config JSONs all retire. Onboarding becomes Terraform (create the repo, secrets, App install) followed by `copier copy`.

## Migration sketch (if B)

1. Classes 1 to 3 first, as the other phases land. Each one shrinks what the template needs to carry.
2. Create the template repo with the class 4 files for one capability (`powershell-module`), and a Tier 2 `template-sync` workflow.
3. Adopt one PSTools repo: `copier copy` over the top, review the diff, commit the answers. Confirm a no-op update is a no-op.
4. Release a trivial template change and watch it arrive as a PR via dispatch.
5. Adopt the other PSTools repos, then add `rust-app` and `container` for `bsdev`.
6. Add class 5 files once class 4 is boring.
7. Delete the generator.

## Decisions needed

- **D1.** Copier (B), or automate the generator (A)? (Leaning B.)
- **D2.** One template versioned as a whole with capability answers, or one template per capability with separate answers files? (Leaning one template, matching the Phase 1 Tier 2 rule. Per-capability means several PRs and version lines per repo.)
- **D3.** Accept generic org-wide `CONTRIBUTING.md` and PR templates (class 2), or keep per-capability ones as owned files?
- **D4.** Publish Brownserve dev container images and/or Features, so devcontainer files become references?
- **D5.** Trigger: dispatch plus weekly schedule, or spike the Dependabot doorbell (G)?
- **D6.** Should the Copier answers file and the Phase 2 project config be the same file?
- **D7.** Is ejecting a file allowed, and should it need a reason recorded in the answers?
- **D8.** Template repo name, and whether it is the same repo as the Phase 1 Tier 2 workflows. (Probably not: different release cadence, and the "workflows repo updates itself" pitfall.)

## Things to verify

Believed true from docs, not yet confirmed with a spike.

- **V1.** `copier update` keeps a Dependabot-bumped SHA in a stub when the template changes a different line in the same file.
- **V2.** Custom `_envops` delimiters let workflow files keep `${{ }}` untouched.
- **V3.** Excluding a previously generated file via `_exclude` deletes it on update, rather than just no longer managing it.
- **V4.** A version-free manifest scaffold plus `dotnet add package` in a migration coexists with Dependabot as described.
- **V5.** Adoption with `copier copy` over an existing repo produces a sensible first diff and a clean no-op second update.
- **V6.** markdownlint `extends` and cSpell `import` can reference a shared file in both VS Code and CI without adding npm to non-JS repos.
- **V7.** Org `.github` default PR templates and `CONTRIBUTING.md` apply to private repos on the free tier. The docs say "regardless of visibility".
- **V8.** PRs opened with the Brownserve CI App token and `sign-commits: true` satisfy signed-commit protection and trigger required checks.
- **V9.** The G variant: raising permissions on a Dependabot-triggered run, pushing with an App key held as a Dependabot secret, and CI running on the result.
- **V10.** `copier check-update` output is usable as a cheap "are we behind" check for a dashboard or the schedule.

## Further out

Noted for completeness.

- **Org rulesets requiring workflows** would remove stubs entirely for PR checks, but requiring workflows at org level is Enterprise Cloud only.
- **GitHub template repositories** (`is_template`, Terraform's `template` block) only help at creation, never on update. Copier covers creation too.
- **Fewer repos.** Merging PSCommon, PSSourceControl and PSBuildTools into one repo would cut three copies of everything to one. It's a big change with its own trade-offs (release cadence, Terraform checks, NuGet package layout), but it attacks the problem at the root.

## Out of scope but noticed

- In `Compare-BrownserveRepository` the unparsable-files guard is `{ throw ... }` inside the `if`, which creates a script block instead of running it. Unparsable files never stop an update.
- `Update-BrownserveRepository` declares `-Force` but never passes it to `Compare-BrownserveRepository`.
- `Update-BrownserveRepository` logs `"Creating directory '$Directory.Path)'"`, which prints the object and a stray bracket.
- `pages/index.md` is overwritten on every update, so any hand-written docs landing page is lost.
