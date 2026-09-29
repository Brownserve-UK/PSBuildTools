<#
.SYNOPSIS
    Generates the CI workflow files for a repository's components.
.DESCRIPTION
    Resolves the requested components and describes what CI has to do for them (which jobs run on a pull request,
    what staging and releasing need, the secrets and permissions involved) without tying it to a provider. That
    description is then turned into workflow files for the chosen provider.
    Only 'GitHubActions' is implemented, its workflows are thin callers of the reusable workflows in
    Brownserve-UK/actions, pinned by commit SHA. Any other provider throws.
    Nothing is written to disk. Each file is returned as an object with a 'Path' (relative to the repository root,
    using forward slashes) and its 'Content'.
.PARAMETER Provider
    The CI/CD provider to generate configuration for.
.PARAMETER Components
    The components the repository is configured with. 'Core' is always included and should not be listed
    explicitly.
.PARAMETER ComponentOptions
    Options for the requested components, keyed by component name. For example, a 'PowerShellModule'
    repository's metadata is supplied via '@{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }'.
.PARAMETER RepoName
    The name of the repository, used as the checkout path and as the GitHub repository name passed to the build.
.PARAMETER Owner
    The account that owns the repository. Not currently used by the GitHubActions provider, as the generated
    'build.ps1' already carries the owner.
.EXAMPLE
    New-BrownserveCIConfiguration -Provider GitHubActions -Components RustBinary, ContainerImage -ComponentOptions @{ ContainerImage = @{ Context = 'image' } } -RepoName 'bsdev'
    Returns the workflow files for a repository that builds a Rust binary and a container image.
.EXAMPLE
    $ModuleInfo = @{ Name = 'Brownserve.Example'; Description = '...'; GUID = (New-Guid); Tags = @('example') }
    New-BrownserveCIConfiguration -Provider GitHubActions -Components PowerShellModule, MkDocs -ComponentOptions @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } } -RepoName 'Brownserve.Example'
    Returns the workflow files for a PowerShell module repository with MkDocs documentation.
#>
function New-BrownserveCIConfiguration
{
    [CmdletBinding()]
    param
    (
        # The CI/CD provider to generate configuration for
        [Parameter(Mandatory = $true)]
        [BrownserveCICD]
        $Provider,

        # The components the repository is configured with, 'Core' is always included automatically
        [Parameter(Mandatory = $false)]
        [string[]]
        $Components = @(),

        # Options for the requested components, keyed by component name
        [Parameter(Mandatory = $false)]
        [hashtable]
        $ComponentOptions = @{},

        # The name of the repository
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $RepoName,

        # The account that owns the repository
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK'
    )
    process
    {
        if ($Provider -ne [BrownserveCICD]::GitHubActions)
        {
            throw "CI configuration for the '$Provider' provider is not implemented."
        }

        try
        {
            $ComponentDefinitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
            $ResolvedComponents = Resolve-BrownserveRepoComponent -Name $Components -Options $ComponentOptions -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to resolve repository components.`n$($_.Exception.Message)"
        }

        try
        {
            $Plan = Get-BrownserveCIPlan `
                -ResolvedComponents $ResolvedComponents `
                -ComponentDefinitions $ComponentDefinitions `
                -RepoName $RepoName `
                -Owner $Owner `
                -ErrorAction 'Stop'
            return New-BrownserveGitHubActionsConfiguration -Plan $Plan -ComponentDefinitions $ComponentDefinitions -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to generate CI configuration.`n$($_.Exception.Message)"
        }
    }
}
