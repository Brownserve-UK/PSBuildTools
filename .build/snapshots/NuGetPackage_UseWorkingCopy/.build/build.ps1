<#
.SYNOPSIS
    Builds, tests and releases this repository via Invoke-Build and Pester.
#>
[CmdletBinding()]
param
(
    # The name of the default branch
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $DefaultBranch = 'main',

    # The name of the branch you are running on, this is used to work out if the release is production or pre-release
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $BranchName,

    # The build to run
    [Parameter(
        Mandatory = $False
    )]
    [ValidateSet('Build', 'BuildAndTest', 'BuildTestAndCheck', 'StageRelease', 'DryRun', 'Release')]
    [string]
    $Build = 'Build',

    # When preparing a release this denotes the type of changes that have been made, used to determine the version number to use for the release
    [Parameter(
        Mandatory = $False
    )]
    [ValidateSet('major', 'minor', 'patch')]
    [string]
    $ReleaseType = 'minor',

    # The various places to publish to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateSet('nuget', 'GitHub', 'CustomNugetFeeds')]
    [string[]]
    $PublishTo,

    # The GitHub organisation/account that owns this repository
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GitHubRepoOwner = 'Brownserve-UK',

    # The GitHub repo that contains this repository
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GitHubRepoName,

    # GitHub token used during the StageRelease build, must have Read/Write pull request and Read issue permissions
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GitHubStageReleaseToken,

    # GitHub token used during the Release build, must have Read/write release permissions
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GitHubReleaseToken,

    # The API key to use when publishing to a NuGet feed
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $NugetFeedApiKey,

    # Any custom/private NuGet feeds to publish to
    [Parameter(
        Mandatory = $False
    )]
    [hashtable[]]
    $CustomNugetFeeds
)
$ErrorActionPreference = 'Stop'
if (!$BranchName)
{
    $BranchName = & git rev-parse --abbrev-ref HEAD
}
if (!$BranchName)
{
    $BranchName = 'preview'
}
$BranchName = $BranchName -replace 'refs\/heads\/', ''

try
{
    Write-Verbose 'Starting build script'
    $initScriptPath = Join-Path $PSScriptRoot -ChildPath '_init.ps1' | Convert-Path
    . $initScriptPath
}
catch
{
    Write-Error "Failed to init repo.`n$($_.Exception.Message)"
}

$RequiredToolchains = @(
    @{ Component = 'NuGetPackage'; Tools = @('mono'); Targets = @('DryRun', 'Release'); Platform = 'NonWindows'; SkipIf = { $false } }
)
$MissingTools = [System.Collections.Generic.List[string]]::new()
foreach ($Requirement in $RequiredToolchains)
{
    if ($Requirement.Targets -notcontains $Build)
    {
        continue
    }
    if (& $Requirement.SkipIf)
    {
        continue
    }
    if ($Requirement.Platform -eq 'Windows' -and -not $IsWindows)
    {
        continue
    }
    if ($Requirement.Platform -eq 'NonWindows' -and $IsWindows)
    {
        continue
    }
    foreach ($Tool in $Requirement.Tools)
    {
        if (!(Get-Command $Tool -ErrorAction SilentlyContinue))
        {
            $MissingTools.Add("'$Tool' (required by $($Requirement.Component))")
        }
    }
}
if ($MissingTools.Count -gt 0)
{
    throw "The following tools are required to run this build but were not found on PATH:`n$($MissingTools -join "`n")"
}

try
{
    $BuildParams = @{
        File          = (Join-Path -Path $global:BrownserveRepoBuildTasksDirectory -ChildPath 'build_tasks.ps1' | Convert-Path)
        Task          = $Build
        BranchName    = $BranchName
        DefaultBranch = $DefaultBranch
    }
    if ($ReleaseType) { $BuildParams.Add('ReleaseType', $ReleaseType) }
    if ($GitHubRepoOwner) { $BuildParams.Add('GitHubRepoOwner', $GitHubRepoOwner) }
    if ($GitHubRepoName) { $BuildParams.Add('GitHubRepoName', $GitHubRepoName) }
    if ($GitHubStageReleaseToken) { $BuildParams.Add('GitHubStageReleaseToken', $GitHubStageReleaseToken) }
    if ($GitHubReleaseToken) { $BuildParams.Add('GitHubReleaseToken', $GitHubReleaseToken) }
    if ($PublishTo) { $BuildParams.Add('PublishTo', $PublishTo) }
    if ($NugetFeedApiKey) { $BuildParams.Add('NugetFeedApiKey', $NugetFeedApiKey) }
    if ($CustomNugetFeeds) { $BuildParams.Add('CustomNugetFeeds', $CustomNugetFeeds) }
    Write-Verbose "Invoking build: $Build"
    Invoke-Build @BuildParams -Verbose:($PSBoundParameters['Verbose'] -eq $true)
}
catch
{
    Write-Error $_.Exception.Message
}
