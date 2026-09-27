# Contributing

Pull requests are welcome. Please read this guide before submitting.

## Skill conventions

- Each skill lives in its own directory under `skills/`, named after the skill.
- Every skill must contain a `SKILL.md` with `name` and `description` in its frontmatter.
- The `name` in the frontmatter must match the directory name.
- Keep supporting files (scripts, references, assets) inside the skill's own directory.

## Documentation site

The documentation site is an [Astro](https://astro.build) project in the `pages/` directory.

```sh
cd pages
npm install
npm run dev
```

## Running the checks locally

```sh
pwsh ./.build/build.ps1 -Build BuildTestAndCheck
```

## Commit and PR requirements

> **Please Note:**
> Our branch protection rules **require** all commits to be [signed](https://docs.github.com/en/github/authenticating-to-github/managing-commit-signature-verification/signing-commits).
> While we can rebase and sign commits for you it's much more likely that your PR will be merged promptly if you ensure your commits are signed before submitting the PR.

We use the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard for PR titles and **this is a hard requirement.** Your PR title must begin with a recognised prefix so that an automated workflow can classify the change for the changelog.

Supported prefixes (brackets are optional):

| Prefix examples | Type |
| --- | --- |
| `[feat]:` `feat:` `[feature]:` `feature:` | New feature or enhancement |
| `[fix]:` `fix:` `[bug]:` `bug:` | Bug fix |
| `[docs]:` `docs:` `[doc]:` `doc:` | Documentation update |
| `[ci]:` `ci:` `[cicd]:` `cicd:` | CI/CD changes |
| `[chore]:` `[refactor]:` `[ops]:` `[test]:` `[style]:` (and without brackets) | Maintenance |

Add `!` before the colon to flag a breaking change, e.g. `feat!: rename a skill`.

> **Please Note:**
> If your PR title does not match a recognised prefix the check will fail and a comment will be posted on the PR explaining what to fix. Simply update the title and the checks will re-run automatically.
