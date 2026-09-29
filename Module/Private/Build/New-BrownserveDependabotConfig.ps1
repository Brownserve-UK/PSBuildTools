<#
.SYNOPSIS
    Generates a dependabot.yml config file for a Brownserve repository.
.DESCRIPTION
    Builds a dependabot.yml from an array of update definitions. Each entry specifies
    a package ecosystem, the directory to scan, and the update schedule interval.
    Optionally a Cooldown hashtable with a DefaultDays key adds a cooldown block so
    Dependabot waits before opening PRs for newly published versions.
    An optional Ignore array of dependency names adds an ignore block so Dependabot leaves those dependencies alone.
#>
function New-BrownserveDependabotConfig
{
    [CmdletBinding()]
    param
    (
        # The list of ecosystems to monitor. Each entry must contain Ecosystem, Directory, and Interval keys.
        # An optional Cooldown hashtable with a DefaultDays key emits a cooldown block.
        # An optional Ignore array of dependency names emits an ignore block.
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
            if ($Update.Cooldown)
            {
                $Lines += '    cooldown:'
                $Lines += "      default-days: $($Update.Cooldown.DefaultDays)"
            }
            if ($Update.Ignore)
            {
                $Lines += '    ignore:'
                foreach ($IgnoredDependency in $Update.Ignore)
                {
                    $Lines += "      - dependency-name: `"$IgnoredDependency`""
                }
            }
            if ($i -lt $Last)
            {
                $Lines += ''
            }
        }
        return $Lines -join "`n"
    }
}
