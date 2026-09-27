<#
.SYNOPSIS
    Builds, tests and releases the PowerShell module via Invoke-Build and Pester.
#>
[CmdletBinding()]
param
(
    # The PowerShell module information to use
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [psobject]
    $ModuleInfo,

    # The author of the module
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $ModuleAuthor = 'Brownserve UK',

    # The name of the default branch
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $DefaultBranch = 'main',

    # The name of the branch you are running on
    # this is used to work out if the release is production or pre-release
    [Parameter(
        Mandatory = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $BranchName,

    # The build to run, defaults to build whereby the module is built but no testing is performed
    [Parameter(
        Mandatory = $false
    )]
    [ValidateSet(
        'Build',
        'BuildAndImport',
        'BuildWithDocs',
        'BuildAndTest',
        'BuildTestAndCheck',
        'StageRelease',
        'DryRun',
        'Release'
    )]
    [AllowEmptyString()]
    [string]
    $Build = 'BuildWithDocs',

    # When preparing a release this denotes the type of changes that have been made.
    # This is used to determine the version number to use for the release.
    # For more information check the RELEASING.md file.
    [Parameter(
        Mandatory = $false
    )]
    [ValidateSet(
        'major',
        'minor',
        'patch'
    )]
    [string]
    $ReleaseType = 'minor',

    # The various places to publish to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('nuget', 'PSGallery', 'GitHub', 'CustomNugetFeeds')]
    [string[]]
    $PublishTo,

    # The GitHub organisation/account that owns this module
    [Parameter(
        Mandatory = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubRepoOwner = 'Brownserve-UK',

    # The GitHub repo that contains this module, it's needed to build up documentation URI's
    [Parameter(
        Mandatory = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubRepoName,

    # GitHub token used during the StageRelease build, must have the following permissions:
    #   * Read/Write pull requests
    #   * Read issues
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $GitHubStageReleaseToken,

    # GitHub token used during the Release build, must have the following permissions:
    #   * Read/write releases
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $GitHubReleaseToken,

    # The API key to use when publishing to a NuGet feed, this is always needed but may not always be used
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $NugetFeedApiKey,

    # The API key to use when publishing to the PSGallery
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $PSGalleryAPIKey,

    # Any custom/private NuGet feeds to publish to
    [Parameter(
        Mandatory = $False
    )]
    [hashtable[]]
    $CustomNugetFeeds
)
# Always stop on errors
$ErrorActionPreference = 'Stop'
# If we don't have a branch name then try to work it out automatically
if (!$BranchName)
{
    $BranchName = & git rev-parse --abbrev-ref HEAD
}
# If we still don't have a branch name then set it to something sensible
if (!$BranchName)
{
    $BranchName = 'preview'
}
# Depending on how we got the branch name we may need to remove the full ref
$BranchName = $BranchName -replace 'refs\/heads\/', ''

# If we're not passing in the module information via the parameter try to load it from our well-known file.
if (!$ModuleInfo)
{
    try
    {
        $ModuleInfo = Get-Content (Join-Path $PSScriptRoot 'ModuleInfo.json') -Raw | ConvertFrom-Json
    }
    catch
    {
        throw 'Failed to load module information.'
    }
    Write-Verbose "Loaded module information from ModuleInfo.json:`n$($ModuleInfo | Out-String)"
}

# Run the init script
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

# Invoke our build task
try
{
    $BuildParams = @{
        File              = (Join-Path -Path $global:BrownserveRepoBuildTasksDirectory -ChildPath 'build_tasks.ps1' | Convert-Path)
        Task              = $Build
        BranchName        = $BranchName
        DefaultBranch     = $DefaultBranch
        ModuleName        = $ModuleInfo.Name
        ModuleDescription = $ModuleInfo.Description
        ModuleAuthor      = $ModuleAuthor
        ModuleGuid        = $ModuleInfo.GUID
        ModuleTags        = $ModuleInfo.Tags
    }
    if ($ReleaseType)
    {
        $BuildParams.Add('ReleaseType', $ReleaseType)
    }
    if ($GitHubRepoOwner)
    {
        $BuildParams.Add('GitHubRepoOwner', $GitHubRepoOwner)
    }
    if ($GitHubRepoName)
    {
        $BuildParams.Add('GitHubRepoName', $GitHubRepoName)
    }
    if ($NugetFeedApiKey)
    {
        $BuildParams.Add('NugetFeedApiKey', $NugetFeedApiKey)
    }
    if ($PSGalleryAPIKey)
    {
        $BuildParams.Add('PSGalleryAPIKey', $PSGalleryAPIKey)
    }
    if ($GitHubStageReleaseToken)
    {
        $BuildParams.Add('GitHubStageReleaseToken', $GitHubStageReleaseToken)
    }
    if ($GitHubReleaseToken)
    {
        $BuildParams.Add('GitHubReleaseToken', $GitHubReleaseToken)
    }
    if ($CustomNugetFeeds)
    {
        $BuildParams.Add('CustomNugetFeeds', $CustomNugetFeeds)
    }
    if ($PublishTo)
    {
        $BuildParams.Add('PublishTo', $PublishTo)
    }
    Write-Verbose "Invoking build: $Build"
    Invoke-Build @BuildParams -Verbose:($PSBoundParameters['Verbose'] -eq $true)
}
catch
{
    Write-Error $_.Exception.Message
}
