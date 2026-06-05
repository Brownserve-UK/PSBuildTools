<#
.SYNOPSIS
    This contains the build tasks for Invoke-Build to use.
    Each task is documented with a synopsis and description to explain what it does.
#>
[CmdletBinding()]
param
(
    # The Docker image name (without tag)
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $ImageName = $Global:BrownserveRepoName,

    # The branch this is being built from
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $BranchName,

    # The default branch for this repository
    [Parameter(
        Mandatory = $true
    )]
    [string]
    $DefaultBranch,

    # The type of changes that this version contains (used to determine the version number)
    [Parameter(
        Mandatory = $false
    )]
    [ValidateSet(
        'major',
        'minor',
        'patch'
    )]
    [string]
    $ReleaseType,

    # The various places to publish to
    [Parameter(
        Mandatory = $false
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('DockerHub', 'GHCR', 'GitHub')]
    [string[]]
    $PublishTo,

    # The GitHub organisation/account to publish the release to
    [Parameter(
        Mandatory = $true
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubRepoOwner,

    # The GitHub repo name
    [Parameter(
        Mandatory = $false
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $GitHubRepoName = $Global:BrownserveRepoName,

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

    # DockerHub username, required when publishing to DockerHub
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $DockerHubUsername,

    # DockerHub access token, required when publishing to DockerHub
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $DockerHubToken,

    # Token used to authenticate with GitHub Container Registry (ghcr.io).
    # Requires packages:write scope. Typically the workflow's GITHUB_TOKEN.
    [Parameter(
        Mandatory = $false
    )]
    [string]
    $GHCRToken
)

# Docker requires image names to be lowercase
$ImageName = $ImageName.ToLower()

# Script-scoped variables populated by tasks
$script:Release = $false
$script:Stage = $false
$script:Changelog = $null
$script:CurrentVersion = $null
$script:NewVersion = $null
$script:ReleaseNotes = $null
$script:StagingBranchName = $null
$script:PRLink = $null
$script:TrackedFiles = @()
$script:ChangelogPath = Join-Path $Global:BrownserveRepoRootDirectory 'CHANGELOG.md'

<#
.SYNOPSIS
    Validates that all parameters required to publish a release have been provided.
#>
task CheckPublishingParameters {
    if (!$PublishTo)
    {
        throw 'PublishTo must be set when performing a release'
    }
    if ('DockerHub' -in $PublishTo)
    {
        if (!$DockerHubUsername)
        {
            throw 'DockerHubUsername must be provided when publishing to DockerHub'
        }
        if (!$DockerHubToken)
        {
            throw 'DockerHubToken must be provided when publishing to DockerHub'
        }
    }
    if ('GHCR' -in $PublishTo)
    {
        if (!$GHCRToken)
        {
            throw 'GHCRToken must be provided when publishing to GHCR'
        }
    }
    if ('GitHub' -in $PublishTo)
    {
        if (!$GitHubReleaseToken)
        {
            throw 'GitHubReleaseToken must be provided when publishing to GitHub'
        }
    }
}

<#
.SYNOPSIS
    Validates that all parameters required to stage a release have been provided.
#>
task CheckStagingParameters {
    if (!$GitHubStageReleaseToken)
    {
        throw 'GitHubStageReleaseToken must be set when staging a release'
    }
}

<#
.SYNOPSIS
    Sets up additional variables required for staging a release.
#>
task SetStagingVariables {
    Write-Verbose 'Setting staging variables'
    $script:Stage = $true
}

<#
.SYNOPSIS
    Sets up additional variables required for a release.
#>
task SetReleaseVariables {
    Write-Verbose 'Setting release variables'
    $script:Release = $true
}

<#
.SYNOPSIS
    Reads the changelog and extracts the version history.
#>
task GetReleaseHistory {
    Write-Build White 'Getting release history'
    $script:Changelog = Read-BrownserveChangelog `
        -ChangelogPath $script:ChangelogPath
    if ($script:Release -ne $true)
    {
        $script:CurrentVersion = ($script:Changelog.VersionHistory | Where-Object { !$_.PreRelease } | Select-Object -First 1).Version
    }
    else
    {
        $script:CurrentVersion = $script:Changelog.LatestVersion.Version
    }
    Write-Verbose "Current version: $script:CurrentVersion"
}

<#
.SYNOPSIS
    Determines the new version number based on the release type.
#>
task SetVersion GetReleaseHistory, {
    Write-Build White 'Setting version'
    if (!$ReleaseType)
    {
        throw 'ReleaseType must be set when staging or releasing'
    }
    $script:NewVersion = switch ($ReleaseType)
    {
        'major' { [semver]::new($script:CurrentVersion.Major + 1, 0, 0) }
        'minor' { [semver]::new($script:CurrentVersion.Major, $script:CurrentVersion.Minor + 1, 0) }
        'patch' { [semver]::new($script:CurrentVersion.Major, $script:CurrentVersion.Minor, $script:CurrentVersion.Patch + 1) }
    }
    Write-Verbose "New version: $script:NewVersion"
    $script:StagingBranchName = "release/$script:NewVersion"
}

<#
.SYNOPSIS
    Creates a new changelog entry for the upcoming release.
#>
task CreateChangelogEntry SetVersion, {
    if ($script:CurrentVersion -eq $script:NewVersion)
    {
        throw 'Current version and new version are the same, cannot create changelog entry'
    }
    Write-Build White "Creating new changelog entry for '$script:NewVersion'"
    $NewChangelogEntryParams = @{
        Version         = $script:NewVersion
        RepositoryOwner = $GitHubRepoOwner
        RepositoryName  = $GitHubRepoName
        ChangelogObject = $script:Changelog
        SinceVersion    = $script:CurrentVersion
    }
    if ($GitHubStageReleaseToken)
    {
        $NewChangelogEntryParams.Add('Auto', $true)
        $NewChangelogEntryParams.Add('GitHubToken', $GitHubStageReleaseToken)
    }
    else
    {
        throw 'GitHub token not provided, cannot generate release notes'
    }
    try
    {
        $script:NewReleaseNotes = New-BrownserveChangelogEntry @NewChangelogEntryParams
    }
    catch
    {
        throw "Failed to create changelog entry.`n$($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Updates the changelog with the new release notes.
#>
task UpdateChangelog CreateChangelogEntry, {
    Write-Build White 'Updating changelog'
    try
    {
        $script:Changelog | Add-BrownserveChangelogEntry `
            -NewContent $script:NewReleaseNotes `
            -ErrorAction 'Stop'
    }
    catch
    {
        throw "Failed to update changelog.`n$($_.Exception.Message)"
    }
    $script:TrackedFiles += ($script:ChangelogPath | Convert-Path)
}

<#
.SYNOPSIS
    Checks out a new staging branch and commits any tracked file changes.
#>
task CommitTrackedChanges {
    Write-Build White "Creating staging branch '$script:StagingBranchName'"
    try
    {
        New-GitBranch -BranchName $script:StagingBranchName -ErrorAction 'Stop'
        $script:TrackedFiles | ForEach-Object {
            Add-GitFileToIndex -Path $_ -ErrorAction 'Stop'
        }
        New-GitCommit -Message "Prepare for $script:NewVersion" -ErrorAction 'Stop'
        Push-GitBranch -BranchName $script:StagingBranchName -ErrorAction 'Stop'
    }
    catch
    {
        throw "Failed to commit tracked changes.`n$($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Creates a pull request for the staged release.
#>
task CreatePullRequest CommitTrackedChanges, {
    Write-Build White 'Creating pull request'
    try
    {
        $Body = @'
This PR was automatically generated.
Please review the changes and merge if they look good.
'@
        $PullRequestParams = @{
            BaseBranch      = $DefaultBranch
            HeadBranch      = $script:StagingBranchName
            Title           = "Prepare for $script:NewVersion"
            Body            = $Body
            GitHubToken     = $GitHubStageReleaseToken
            RepositoryName  = $GitHubRepoName
            RepositoryOwner = $GitHubRepoOwner
        }
        $PRDetails = New-GitHubPullRequest @PullRequestParams
        $script:PRLink = $PRDetails.html_url
        Write-Debug "PRLink: $script:PRLink"
    }
    catch
    {
        throw "Failed to create pull request.`n$($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Builds the Docker image.
#>
task Build {
    Write-Build White "Building Docker image '$ImageName'"
    try
    {
        exec { docker build -t "${ImageName}:latest" . }
    }
    catch
    {
        throw "Docker build failed.`n$($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Builds the Docker image and verifies it completes successfully.
    Used by the CI pipeline on pull requests.
#>
task BuildTestAndCheck Build, {}

<#
.SYNOPSIS
    Publishes the Docker image to the selected registries and creates a GitHub release.
#>
task PublishRelease GetReleaseHistory, Build, {
    Write-Build White 'Publishing release'
    $script:ReleaseVersion = $script:Changelog.LatestVersion.Version.ToString()
    $script:ReleaseNotes = $script:Changelog.LatestVersion.ReleaseNotes -join "`n"

    if ('DockerHub' -in $PublishTo)
    {
        Write-Build White 'Publishing to DockerHub'
        try
        {
            exec { docker login -u $DockerHubUsername -p $DockerHubToken }
            exec { docker tag "${ImageName}:latest" "${DockerHubUsername}/${ImageName}:$script:ReleaseVersion" }
            exec { docker tag "${ImageName}:latest" "${DockerHubUsername}/${ImageName}:latest" }
            exec { docker push "${DockerHubUsername}/${ImageName}:$script:ReleaseVersion" }
            exec { docker push "${DockerHubUsername}/${ImageName}:latest" }
        }
        catch
        {
            throw "Failed to publish to DockerHub.`n$($_.Exception.Message)"
        }
    }

    if ('GHCR' -in $PublishTo)
    {
        Write-Build White 'Publishing to GitHub Container Registry'
        $GHCRImage = "ghcr.io/${GitHubRepoOwner}/${ImageName}"
        try
        {
            exec { docker login ghcr.io -u $GitHubRepoOwner -p $GHCRToken }
            exec { docker tag "${ImageName}:latest" "${GHCRImage}:$script:ReleaseVersion" }
            exec { docker tag "${ImageName}:latest" "${GHCRImage}:latest" }
            exec { docker push "${GHCRImage}:$script:ReleaseVersion" }
            exec { docker push "${GHCRImage}:latest" }
        }
        catch
        {
            throw "Failed to publish to GHCR.`n$($_.Exception.Message)"
        }
    }
    else
    {
        Write-Verbose 'GHCR not targeted, skipping...'
    }

    if ('GitHub' -in $PublishTo)
    {
        Write-Build White 'Creating GitHub release'
        try
        {
            $GitHubReleaseParams = @{
                TagName         = $script:ReleaseVersion
                ReleaseName     = $script:ReleaseVersion
                ReleaseNotes    = $script:ReleaseNotes
                GitHubToken     = $GitHubReleaseToken
                RepositoryName  = $GitHubRepoName
                RepositoryOwner = $GitHubRepoOwner
            }
            New-GitHubRelease @GitHubReleaseParams
        }
        catch
        {
            throw "Failed to create GitHub release.`n$($_.Exception.Message)"
        }
    }
    else
    {
        Write-Verbose 'GitHub not targeted, skipping...'
    }
}

<#
.SYNOPSIS
    Stages a release by updating the changelog and creating a pull request.
    This is the first step in a two-stage release process.
#>
task StageRelease CheckStagingParameters, SetStagingVariables, CreateChangelogEntry, UpdateChangelog, CreatePullRequest, {
    $BuildMessage = @"
The release has been successfully staged and a pull request has been created.
Please review the changes at $script:PRLink and merge if they look good.
"@
    Write-Build Green $BuildMessage
}

<#
.SYNOPSIS
    Publishes the release by pushing Docker images and creating a GitHub release.
    Run this after merging the pull request created by StageRelease.
#>
task Release CheckPublishingParameters, SetReleaseVariables, PublishRelease, {}
