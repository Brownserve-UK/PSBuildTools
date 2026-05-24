# Contributing

Pull requests are welcome but please do bear in mind that these tools are designed specifically to work with Brownserve projects and are in use across various production CI/CD pipelines, therefore we may not be able to accommodate all requests.

Code should follow the guidelines below and must have complete documentation before being submitted (it will fail CI/CD if it doesn't).
Documentation will be generated for you when you run the `BuildWithDocs` task locally however some sections will be missing and will need to be completed manually. These will be surrounded by `{{ }}` to make them easy to find (e.g. `{{ Fill in Synopsis }}`).

> **Please Note:**
> Our branch protection rules **require** all commits to be [signed](https://docs.github.com/en/github/authenticating-to-github/managing-commit-signature-verification/signing-commits).
> While we can rebase and sign commits for you it's much more likely that your PR will be merged promptly if you ensure your commits are signed before submitting the PR.

We use the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard for PR titles and **this is a hard requirement.** Your PR title must begin with a recognised prefix so that an automated workflow can classify the change for the changelog. A second check will block merge if no valid label has been applied.

Supported prefixes (brackets are optional):

| Prefix examples | Type |
| --- | --- |
| `[feat]:` `feat:` `[feature]:` `feature:` | New feature or enhancement |
| `[fix]:` `fix:` `[bug]:` `bug:` | Bug fix |
| `[docs]:` `docs:` `[doc]:` `doc:` | Documentation update |
| `[ci]:` `ci:` `[cicd]:` `cicd:` | CI/CD changes |
| `[chore]:` `[refactor]:` `[ops]:` `[test]:` `[style]:` (and without brackets) | Maintenance |

Add `!` before the colon to flag a breaking change, e.g. `[feat!]: remove legacy parameter` or `fix!: rename cmdlet`.

> **Please Note:**
> If your PR title does not match a recognised prefix the check will fail and a comment will be posted on the PR explaining what to fix. Simply update the title and the checks will re-run automatically.

## Style Guidelines

### Writing cmdlets

#### Don't construct paths manually

Don't form paths by passing in separators (e.g. `C:\`, `/usr/`), use the tools PowerShell gives you:

- [`Resolve-Path`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/resolve-path?view=powershell-7.1) can be used to validate user submitted paths or resolve the path to commands/aliases.
- [`Join-Path`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.1) can be used to construct paths (top tip: you can specify multiple values in `-AdditionalChildPaths`)
- [`Convert-Path`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/convert-path?view=powershell-7.1) converts a `PSPath` to the standard path format for your OS, which avoids issues with environment variables.

All these cmdlets handle path separators automatically and will ensure that the path is valid for the current operating system, giving your code a much higher chance of working cross-platform.

#### OS specific cmdlets

By default we treat all cmdlets as cross-platform. If your code will only work on certain operating systems you should call `Test-OperatingSystem` at the beginning of your cmdlet with the supported OSes as the parameter. An exception will be raised if the current OS is not in the supported list.

#### Use `Begin`, `Process` and `End` blocks

Even if your cmdlet doesn't support pipeline input you should still use the `Begin`, `Process` and `End` blocks. This allows us to easily add pipeline support in the future and keeps the code consistent.

#### Define parameter properties

When defining parameters you should always specify the parameter properties, including `Mandatory`, `Position` and `ValueFromPipelineByPropertyName` where applicable.

#### Define parameter types

Always define a type for each parameter. This allows PowerShell to validate input and provide tab completion.

#### Ensure parameter names are consistent

Parameter names should be consistent across all cmdlets. For example if one cmdlet uses `Token` then all cmdlets should use `Token`, not `PAT` or `AccessToken`.

### Writing documentation

#### All `Public` cmdlets must have documentation

All `Public` cmdlets **must** have documentation, and all documentation **must** be complete (CI/CD will fail if it isn't).
Running any of the build tasks will automatically generate the documentation for you, however some sections will be missing and will need to be completed manually. These will be surrounded by `{{ }}` to make them easy to find (e.g. `{{ Fill in Synopsis }}`).
The `BuildAndTest` task includes tests that check for incomplete sections and will highlight them in the build output.

#### Keep the synopsis short

The synopsis should be a concise description of what the cmdlet does, ideally a single line.

#### Documentation must use LF line endings

To keep the git history clean, all documentation must use LF line endings. An `.editorconfig` file is included in the repository to handle this automatically for supported editors. The build tasks will also convert line endings for you when generating documentation.
