<#
.SYNOPSIS
    Formats a Keep a Changelog block for a Brownserve changelog.
.DESCRIPTION
    Creates a properly formatted changelog block following the Keep a Changelog standard.
    Only sections that contain entries are emitted. Section order: Breaking Changes, Added,
    Fixed, Deprecated, Removed, Changed, Security.
#>
function New-BrownserveChangelogBlock
{
    [CmdletBinding()]
    param
    (
        # The version number
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [semver]
        $Version,

        # Optional notice displayed between the version header and the first section
        [Parameter(
            Mandatory = $false,
            Position = 2,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Notice,

        # Breaking changes (non-backwards-compatible)
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $BreakingChanges,

        # New features / additions
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Added,

        # Bug fixes
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Fixed,

        # Deprecations
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Deprecated,

        # Removed features
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Removed,

        # Backwards-compatible changes
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Changed,

        # Security fixes
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]
        $Security,

        # The repository owner
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $RepositoryOwner,

        # The repository name
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $RepositoryName,

        # The repository host
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $RepositoryHost = 'github.com',

        # The previous version, used to generate a comparison link
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName = $true
        )]
        [semver]
        $SinceVersion
    )
    begin {}
    process
    {
        $VersionStr = $Version.ToString()
        $RepoBase = "https://$RepositoryHost/$RepositoryOwner/$RepositoryName"

        $Block = "## [v$VersionStr]($RepoBase/tree/v$VersionStr) ($(Get-Date -Format 'yyyy-MM-dd'))`n"

        if ($Notice)
        {
            if ($Notice -notmatch '^_(.*)_$')
            {
                $Notice = "_$Notice_"
            }
            $Block += "`n$Notice`n"
        }

        $Sections = [ordered]@{
            'Breaking Changes' = $BreakingChanges
            'Added'            = $Added
            'Fixed'            = $Fixed
            'Deprecated'       = $Deprecated
            'Removed'          = $Removed
            'Changed'          = $Changed
            'Security'         = $Security
        }

        foreach ($Name in $Sections.Keys)
        {
            $Entries = $Sections[$Name]
            if ($Entries)
            {
                $Block += "`n### $Name`n`n"
                foreach ($Entry in $Entries)
                {
                    $Block += "- $Entry`n"
                }
            }
        }
    }
    end
    {
        return $Block
    }
}
