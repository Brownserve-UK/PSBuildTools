<#
.SYNOPSIS
    This contains the build tasks for Invoke-Build to use.
#>
[CmdletBinding()]
param
(
    # The type of changes that this version of the release contains, used to determine the version number
    [Parameter(
        Mandatory = $False
    )]
    [ValidateSet('major', 'minor', 'patch')]
    [string]
    $ReleaseType,

    # The branch this is being built from
    [Parameter(
        Mandatory = $True
    )]
    [string]
    $BranchName,

    # The default branch for this repository
    [Parameter(
        Mandatory = $True
    )]
    [string]
    $DefaultBranch,

    # The various places this build might publish to
    [Parameter(
        Mandatory = $False
    )]
    [ValidateSet('nuget', 'GitHub', 'CustomNugetFeeds')]
    [string[]]
    $PublishTo,

    # The GitHub organisation/account this repository lives in
    [Parameter(
        Mandatory = $True
    )]
    [string]
    $GitHubRepoOwner,

    # The GitHub repo name
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GitHubRepoName = $Global:BrownserveRepoName,

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
if (!$GitHubRepoName)
{
    throw 'GitHubRepoName not set'
}
$BranchName = $BranchName -replace 'refs\/heads\/', ''

$TasksDirectory = Join-Path $Global:BrownserveRepoRootDirectory 'tasks'

$ReleaseLifecycleParams = @{
    BranchName      = $BranchName
    DefaultBranch   = $DefaultBranch
    GitHubRepoOwner = $GitHubRepoOwner
    GitHubRepoName  = $GitHubRepoName
}
if ($ReleaseType) { $ReleaseLifecycleParams.Add('ReleaseType', $ReleaseType) }
if ($PublishTo) { $ReleaseLifecycleParams.Add('PublishTo', $PublishTo) }
if ($GitHubStageReleaseToken) { $ReleaseLifecycleParams.Add('GitHubStageReleaseToken', $GitHubStageReleaseToken) }
if ($GitHubReleaseToken) { $ReleaseLifecycleParams.Add('GitHubReleaseToken', $GitHubReleaseToken) }
. (Join-Path $TasksDirectory 'ReleaseLifecycle.tasks.ps1') @ReleaseLifecycleParams

$NuGetPackageParams = @{
    GitHubRepoOwner    = $GitHubRepoOwner
    PackageAuthor      = 'Brownserve UK'
    PackageDescription = 'A test content-only NuGet package used for repository snapshot testing.'
    PackageId          = 'Brownserve.TestPackage'
    PackageTags        = @('brownserve-UK')
}
$NuGetPackageParamsPublishTo = @($PublishTo | Where-Object { $_ -in @('nuget', 'GitHub', 'CustomNugetFeeds') })
if ($NuGetPackageParamsPublishTo.Count -gt 0) { $NuGetPackageParams.Add('PublishTo', $NuGetPackageParamsPublishTo) }
if ($GitHubRepoName) { $NuGetPackageParams.Add('GitHubRepoName', $GitHubRepoName) }
if ($GitHubReleaseToken) { $NuGetPackageParams.Add('GitHubReleaseToken', $GitHubReleaseToken) }
if ($NugetFeedApiKey) { $NuGetPackageParams.Add('NugetFeedApiKey', $NugetFeedApiKey) }
if ($CustomNugetFeeds) { $NuGetPackageParams.Add('CustomNugetFeeds', $CustomNugetFeeds) }
. (Join-Path $TasksDirectory 'NuGetPackage.tasks.ps1') @NuGetPackageParams

. (Join-Path $Global:BrownserveRepoBuildTasksDirectory 'custom.tasks.ps1')
