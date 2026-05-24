function Format-NuGetPackageVersion
{
    [CmdletBinding()]
    param(
        # SemVer version number to format.
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [System.Management.Automation.SemanticVersion]
        $Version,

        # The version of SemanticVersion to format for.
        [Parameter(
            Mandatory = $false,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet(
            '1.0.0',
            '2.0.0'
        )]
        [version]
        $SemanticVersion = '2.0.0'
    )

    begin
    {
        $Return = $null
    }
    process
    {
        # NuGet 4.3.0+ supports SemVer 2.0.0, which allows for a build label and longer pre-release labels.
        if ($SemanticVersion -ge '2.0.0')
        {
            $Return = [string]$Version
        }
        else
        {
            # If we don't have a pre-release label or build label then just return the version, this should be fine for nuget.org
            if (!$Version.PreReleaseLabel -and !$Version.BuildLabel)
            {
                $Return = [string]$Version
            }
            else
            {
                $Return = [string]$Version.Major + '.' + [string]$Version.Minor + '.' + [string]$Version.Patch
                if ($Version.PreReleaseLabel)
                {
                    $PreReleaseLabel = $Version.PreReleaseLabel
                }
                # If we have a build label then append it to the pre-release label as build labels are not supported in SemVer 1.0.0
                if ($Version.BuildLabel)
                {
                    $PreReleaseLabel += $Version.BuildLabel
                }
                if ($Version.PreReleaseLabel)
                {
                    # Shorten the suffix if necessary, to satisfy NuGet's 20 character limit.
                    # This was removed as of https://github.com/NuGet/Home/issues/2735 however it requires NuGet 4.0.0+.
                    # So we only support it when using SemVer 2.0.0.
                    if ($PreReleaseLabel.Length -gt 20)
                    {
                        $PreReleaseLabel = $PreReleaseLabel.SubString(0, 20)
                    }
                    $Return += '-' + $PreReleaseLabel
                }
            }
        }
    }
    end
    {
        if ($Return)
        {
            return $Return
        }
        else
        {
            return $null
        }
    }
}
