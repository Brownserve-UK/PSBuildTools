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
    [ValidateSet('nuget', 'PSGallery', 'GitHub', 'CustomNugetFeeds')]
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

    # The description of the module
    [Parameter(
        Mandatory = $True
    )]
    [string]
    $ModuleDescription,

    # The GUID of the module
    [Parameter(
        Mandatory = $True
    )]
    [guid]
    $ModuleGUID,

    # The name of the PowerShell module being built
    [Parameter(
        Mandatory = $True
    )]
    [string]
    $ModuleName,

    # Any tags to add to the module
    [Parameter(
        Mandatory = $True
    )]
    [string[]]
    $ModuleTags,

    # The author of the module
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $ModuleAuthor = 'Brownserve UK',

    # The API key to use when publishing to a NuGet feed
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $NugetFeedApiKey,

    # The API key to use when publishing to the PSGallery
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $PSGalleryAPIKey,

    # Any custom/private NuGet feeds to publish to
    [Parameter(
        Mandatory = $False
    )]
    [hashtable[]]
    $CustomNugetFeeds,

    # If set, loads the working copy of the module from the module directory instead of the stable version restored by _init.ps1
    [Parameter(
        Mandatory = $False
    )]
    [switch]
    $UseWorkingCopy
)
if (!$GitHubRepoName)
{
    throw 'GitHubRepoName not set'
}
$BranchName = $BranchName -replace 'refs\/heads\/', ''

$TasksDirectory = Join-Path $Global:BrownserveRepoNugetPackagesDirectory 'Brownserve.PSBuildTasks' 'tasks'

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

$PowerShellModuleParams = @{
    GitHubRepoOwner   = $GitHubRepoOwner
    ModuleDescription = $ModuleDescription
    ModuleGUID        = $ModuleGUID
    ModuleName        = $ModuleName
    ModuleTags        = $ModuleTags
}
$PowerShellModuleParamsPublishTo = @($PublishTo | Where-Object { $_ -in @('nuget', 'PSGallery', 'GitHub', 'CustomNugetFeeds') })
if ($PowerShellModuleParamsPublishTo.Count -gt 0) { $PowerShellModuleParams.Add('PublishTo', $PowerShellModuleParamsPublishTo) }
if ($GitHubRepoName) { $PowerShellModuleParams.Add('GitHubRepoName', $GitHubRepoName) }
if ($GitHubReleaseToken) { $PowerShellModuleParams.Add('GitHubReleaseToken', $GitHubReleaseToken) }
if ($ModuleAuthor) { $PowerShellModuleParams.Add('ModuleAuthor', $ModuleAuthor) }
if ($NugetFeedApiKey) { $PowerShellModuleParams.Add('NugetFeedApiKey', $NugetFeedApiKey) }
if ($PSGalleryAPIKey) { $PowerShellModuleParams.Add('PSGalleryAPIKey', $PSGalleryAPIKey) }
if ($CustomNugetFeeds) { $PowerShellModuleParams.Add('CustomNugetFeeds', $CustomNugetFeeds) }
$PowerShellModuleParams.Add('UseWorkingCopy', ($UseWorkingCopy -eq $true))
. (Join-Path $TasksDirectory 'PowerShellModule.tasks.ps1') @PowerShellModuleParams

. (Join-Path $Global:BrownserveRepoBuildTasksDirectory 'custom.tasks.ps1')
