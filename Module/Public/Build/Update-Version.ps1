<#
.SYNOPSIS
    A simple function to increment a semantic version number.
.DESCRIPTION
    This function will increment a semantic version number based on the type of release being done.
    It will also optionally append a pre-release string and/or a build number.
#>
function Update-Version
{
    [CmdletBinding()]
    param
    (
        # The current version that should be updated
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [System.Management.Automation.SemanticVersion]
        $Version,

        # The type of release (major, minor, patch)
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet(
            'major',
            'minor',
            'patch'
        )]
        [string]
        $ReleaseType,

        # An optional pre-release to append to the version number
        [Parameter(
            Mandatory = $false,
            Position = 2,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $PreReleaseString,

        # An optional build number to append to the version number
        [Parameter(
            Mandatory = $false,
            Position = 3,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $BuildNumber
    )
    begin
    {
        $NewVersion = $null
    }
    process
    {
        try
        {
            switch ($ReleaseType)
            {
                'major'
                {
                    $NewVersion = [System.Management.Automation.SemanticVersion]::new($Version.Major + 1, 0, 0)
                }
                'minor'
                {
                    $NewVersion = [System.Management.Automation.SemanticVersion]::new($Version.Major, $Version.Minor + 1, 0)
                }
                'patch'
                {
                    $NewVersion = [System.Management.Automation.SemanticVersion]::new($Version.Major, $Version.Minor, $Version.Patch + 1)
                }
            }
        }
        catch
        {
            throw "Failed to increment version number. `n$($_.Exception.Message)"
        }
        try
        {
            if ($PreReleaseString)
            {
                # Remove invalid characters from the suffix.
                $PreReleaseString = $PreReleaseString -replace '[/]', '-'
                $PreReleaseString = $PreReleaseString -replace '[^0-9A-Za-z-]', ''
                [System.Management.Automation.SemanticVersion]$NewVersion = "$($NewVersion.ToString())-$PreReleaseString"
            }
        }
        catch
        {
            throw "Failed to append pre-release string. `n$($_.Exception.Message)"
        }
        # The build number is always at the end
        try
        {
            if ($BuildNumber)
            {
                [System.Management.Automation.SemanticVersion]$NewVersion = "$($NewVersion.ToString())+$BuildNumber"
            }
        }
        catch
        {
            throw "Failed to append build number. `n$($_.Exception.Message)"
        }
    }
    end
    {
        if ($NewVersion)
        {
            return $NewVersion
        }
        else
        {
            return $null
        }
    }
}