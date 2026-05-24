<#
.SYNOPSIS
    Creates a new Keep a Changelog entry for a given version in the standard Brownserve format.
.DESCRIPTION
    Generates a new changelog entry following the Keep a Changelog standard.
    Providing the -Auto parameter causes the cmdlet to query merged GitHub pull requests since
    the last release and categorise them into sections (Breaking Changes, Added, Fixed,
    Deprecated, Removed, Changed, Security) based on their GitHub labels.
    PRs labelled 'cicd' are excluded from the changelog. PRs labelled 'removed' appear in
    both the Breaking Changes and Removed sections. All other PRs with a 'breaking' label
    appear only in Breaking Changes.
#>
function New-BrownserveChangelogEntry
{
    [CmdletBinding()]
    param
    (
        # The path to the changelog file
        [Parameter(
            Mandatory = $false,
            Position = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]
        $ChangelogPath = (Join-Path $PWD 'CHANGELOG.md'),

        # The version number to use for the new entry
        [Parameter(
            Mandatory = $true,
            Position = 2,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.SemanticVersion]
        $Version,

        # The owner of the repo that the changelog belongs to
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $RepositoryOwner,

        # The name of the repo that the changelog belongs to
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $RepositoryName,

        # The GitHub token to use for API calls (required when using -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $GitHubToken,

        # An optional notice to attach to this release
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Notice,

        # Breaking changes to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $BreakingChanges,

        # New additions to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Added,

        # Bug fixes to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Fixed,

        # Deprecations to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Deprecated,

        # Removed features to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Removed,

        # Backwards-compatible changes to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Changed,

        # Security fixes to include (manual override, used without -Auto)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Security,

        # Attempt to automatically populate the entry from merged PRs and their labels
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [switch]
        $Auto,

        # The version to treat as the baseline when collecting merges.
        # Defaults to the most recent changelog entry, but pass the last stable version here
        # when promoting a pre-release to stable so all changes since the stable release are included.
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [System.Management.Automation.SemanticVersion]
        $SinceVersion,

        # Special hidden parameter to allow the cmdlet to be called from the pipeline
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            DontShow = $true
        )]
        [BrownserveChangeLog]
        $ChangelogObject
    )
    begin
    {
        if ($Auto -and !$GitHubToken)
        {
            throw 'You must provide a GitHub token when using the -Auto parameter'
        }
    }
    process
    {
        $Return = $null

        if (!$ChangelogObject)
        {
            try
            {
                Write-Verbose "Loading changelog from $ChangelogPath"
                $ChangelogObject = Read-BrownserveChangelog -Path $ChangelogPath
            }
            catch
            {
                throw "Failed to read changelog file '$ChangelogPath'.`n$($_.Exception.Message)"
            }
        }

        if ($Version -in $ChangelogObject.VersionHistory.Version)
        {
            throw "Version '$Version' already exists in the changelog"
        }

        $LastReleasedVersion = $ChangelogObject.LatestVersion

        if ($SinceVersion)
        {
            $SinceVersionEntry = $ChangelogObject.VersionHistory |
                Where-Object { $_.Version -eq $SinceVersion } |
                    Select-Object -First 1
            if (!$SinceVersionEntry)
            {
                throw "SinceVersion '$SinceVersion' not found in changelog"
            }
            $LastReleasedVersion = $SinceVersionEntry
        }

        if ($Auto)
        {
            try
            {
                $GetGitMergesParams = @{
                    RepositoryPath = $ChangelogPath
                    ErrorAction    = 'Stop'
                }
                <#
                    When the changelog contains only the 0.0.0 placeholder entry seeded by
                    Initialize-BrownserveRepository, no corresponding git tag exists. Passing it
                    as a reference range to git would fail with "unknown revision or path not in
                    the working tree". For a first release we want all merges from the beginning
                    of the repo, so we omit ReferenceBranch. Get-GitMerges already handles this
                    case by falling back to all-history mode when no ReferenceBranch is given.
                #>
                if (-not $ChangelogObject.HasPlaceholder)
                {
                    $GetGitMergesParams['ReferenceBranch'] = "v$($LastReleasedVersion.Version)"
                }
                $MergesSinceLastRelease = Get-GitMerges @GetGitMergesParams
                if (!$MergesSinceLastRelease)
                {
                    throw 'No merges found since last release'
                }
            }
            catch
            {
                throw "Failed to get git merges since last release.`n$($_.Exception.Message)"
            }

            try
            {
                $PullRequests = Get-GitHubPullRequests `
                    -RepositoryOwner $RepositoryOwner `
                    -RepositoryName $RepositoryName `
                    -GitHubToken $GitHubToken `
                    -State 'closed' `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to get GitHub pull requests.`n$($_.Exception.Message)"
            }

            $PullRequestDetails = @()
            $MergesSinceLastRelease | ForEach-Object {
                $MergeCommit = $_
                $MatchedPR = $PullRequests | Where-Object { $_.merge_commit_sha -eq $MergeCommit }
                if ($MatchedPR)
                {
                    $PullRequestDetails += $MatchedPR
                }
                else
                {
                    Write-Warning "Merge commit '$MergeCommit' has no corresponding pull request, skipping (likely a branch sync merge)"
                }
            }

            foreach ($PR in $PullRequestDetails)
            {
                $Labels = $PR.labels.name
                $Entry = "$($PR.title) in [#$($PR.number)]($($PR.html_url)) by [@$($PR.user.login)]($($PR.user.html_url))"

                if ('removed' -in $Labels)
                {
                    # removed always implies breaking; surfaces in both sections
                    $BreakingChanges += $Entry
                    $Removed += $Entry
                }
                elseif ('breaking' -in $Labels)
                {
                    $BreakingChanges += $Entry
                }
                elseif ('enhancement' -in $Labels)
                {
                    $Added += $Entry
                }
                elseif ('bug' -in $Labels -or 'documentation' -in $Labels)
                {
                    $Fixed += $Entry
                }
                elseif ('deprecation' -in $Labels)
                {
                    $Deprecated += $Entry
                }
                elseif ('security' -in $Labels)
                {
                    $Security += $Entry
                }
                elseif ('maintenance' -in $Labels)
                {
                    $Changed += $Entry
                }
                elseif ('cicd' -in $Labels)
                {
                    Write-Verbose "Skipping CI/CD PR #$($PR.number): '$($PR.title)'"
                }
                else
                {
                    Write-Warning "PR #$($PR.number) '$($PR.title)' has no recognised changelog label, skipping"
                }
            }

            $HasEntries = $BreakingChanges -or $Added -or $Fixed -or $Deprecated -or $Removed -or $Changed -or $Security
            if (!$HasEntries)
            {
                Write-Warning 'No user-facing changes found among merged PRs - the changelog entry will have no sections'
            }
        }
        else
        {
            $HasEntries = $BreakingChanges -or $Added -or $Fixed -or $Deprecated -or $Removed -or $Changed -or $Security
            if (!$HasEntries)
            {
                throw 'You must provide at least one section of entries when not using the -Auto parameter'
            }
        }

        $ChangelogBlockParams = @{
            Version         = $Version
            RepositoryOwner = $RepositoryOwner
            RepositoryName  = $RepositoryName
            SinceVersion    = $LastReleasedVersion.Version
        }
        if ($Notice)          { $ChangelogBlockParams['Notice']         = $Notice         }
        if ($BreakingChanges) { $ChangelogBlockParams['BreakingChanges'] = $BreakingChanges }
        if ($Added)           { $ChangelogBlockParams['Added']          = $Added           }
        if ($Fixed)           { $ChangelogBlockParams['Fixed']          = $Fixed           }
        if ($Deprecated)      { $ChangelogBlockParams['Deprecated']     = $Deprecated      }
        if ($Removed)         { $ChangelogBlockParams['Removed']        = $Removed         }
        if ($Changed)         { $ChangelogBlockParams['Changed']        = $Changed         }
        if ($Security)        { $ChangelogBlockParams['Security']       = $Security        }

        try
        {
            $Return = New-BrownserveChangelogBlock @ChangelogBlockParams -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to create changelog block.`n$($_.Exception.Message)"
        }
    }
    end
    {
        return $Return
    }
}
