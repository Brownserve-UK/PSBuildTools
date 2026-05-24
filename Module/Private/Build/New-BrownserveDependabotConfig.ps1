<#
.SYNOPSIS
    Generates a dependabot.yml config file for a Brownserve repository.
.DESCRIPTION
    Builds a dependabot.yml from an array of update definitions. Each entry specifies
    a package ecosystem, the directory to scan, and the update schedule interval.
#>
function New-BrownserveDependabotConfig
{
    [CmdletBinding()]
    param
    (
        # The list of ecosystems to monitor. Each entry must contain Ecosystem, Directory, and Interval keys.
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Updates
    )
    process
    {
        $Lines = @('---', 'version: 2', 'updates:')
        $Last = $Updates.Count - 1
        for ($i = 0; $i -lt $Updates.Count; $i++)
        {
            $Update = $Updates[$i]
            $Lines += "  - package-ecosystem: $($Update.Ecosystem)"
            $Lines += "    directory: $($Update.Directory)"
            $Lines += '    schedule:'
            $Lines += "      interval: $($Update.Interval)"
            if ($i -lt $Last)
            {
                $Lines += ''
            }
        }
        return $Lines -join "`n"
    }
}
