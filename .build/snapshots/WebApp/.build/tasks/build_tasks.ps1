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
    [ValidateSet('DockerHub', 'GHCR')]
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

    # DockerHub username, required when publishing to DockerHub
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $DockerHubUsername,

    # DockerHub access token, required when publishing to DockerHub
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $DockerHubToken,

    # Token for GitHub Container Registry, needs packages:write
    [Parameter(
        Mandatory = $False
    )]
    [string]
    $GHCRToken
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

$ContainerImageParams = @{
    GitHubRepoOwner   = $GitHubRepoOwner
    DockerContextPath = '.'
}
$ContainerImageParamsPublishTo = @($PublishTo | Where-Object { $_ -in @('DockerHub', 'GHCR') })
if ($ContainerImageParamsPublishTo.Count -gt 0) { $ContainerImageParams.Add('PublishTo', $ContainerImageParamsPublishTo) }
if ($DockerHubUsername) { $ContainerImageParams.Add('DockerHubUsername', $DockerHubUsername) }
if ($DockerHubToken) { $ContainerImageParams.Add('DockerHubToken', $DockerHubToken) }
if ($GHCRToken) { $ContainerImageParams.Add('GHCRToken', $GHCRToken) }
. (Join-Path $TasksDirectory 'ContainerImage.tasks.ps1') @ContainerImageParams

. (Join-Path $Global:BrownserveRepoBuildTasksDirectory 'custom.tasks.ps1')
