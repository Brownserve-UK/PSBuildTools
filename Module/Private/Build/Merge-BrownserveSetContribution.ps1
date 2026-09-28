<#
.SYNOPSIS
    Merges our generated contributions into a structured 'Merged' file whose ownership is tracked as a
    set of strings rather than key/value pairs (currently only '.vscode/extensions.json' recommendations).
.DESCRIPTION
    Entries we contribute ('Ours') that are missing from disk and weren't in the previous baseline are new
    contributions and get added. An entry that was in the baseline but is no longer on disk is a conflict
    (someone has deliberately removed a recommendation we added), unless '-Force' is passed, in which case
    it's re-added. An entry that was in the baseline but that we no longer contribute is removed, so long as
    it's still on disk. Every other entry on disk, that we've never contributed, is always kept, and the
    existing disk ordering is preserved with any new entries appended.
#>
function Merge-BrownserveSetContribution
{
    [CmdletBinding()]
    param
    (
        # The current on-disk entries
        [Parameter(Mandatory = $false)]
        [string[]]
        $Disk = @(),

        # The entries we contributed the last time this file was generated
        [Parameter(Mandatory = $false)]
        [string[]]
        $Baseline = @(),

        # The entries we contribute this time
        [Parameter(Mandatory = $false)]
        [string[]]
        $Ours = @(),

        # Resolve conflicts in favour of re-adding our contributed entries instead of reporting them
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    process
    {
        $DiskList = [System.Collections.Generic.List[string]]::new()
        foreach ($Item in $Disk)
        {
            if ($Item -and !$DiskList.Contains($Item))
            {
                $DiskList.Add($Item)
            }
        }
        $DiskSet = @{}
        $DiskList | ForEach-Object { $DiskSet[$_] = $true }
        $BaselineSet = @{}
        $Baseline | Where-Object { $_ } | ForEach-Object { $BaselineSet[$_] = $true }
        $OursSet = @{}
        $Ours | Where-Object { $_ } | ForEach-Object { $OursSet[$_] = $true }

        $ConflictItems = @()
        $ToReAdd = @()
        foreach ($Item in $Baseline)
        {
            if (!$DiskSet.ContainsKey($Item) -and $OursSet.ContainsKey($Item))
            {
                if ($Force)
                {
                    $ToReAdd += $Item
                }
                else
                {
                    $ConflictItems += $Item
                }
            }
        }

        if ($ConflictItems.Count -gt 0 -and !$Force)
        {
            return [pscustomobject]@{
                Conflict      = $true
                ConflictItems = $ConflictItems
                Merged        = $null
            }
        }

        $Result = [System.Collections.Generic.List[string]]::new()
        foreach ($Item in $DiskList)
        {
            if ($BaselineSet.ContainsKey($Item) -and !$OursSet.ContainsKey($Item))
            {
                continue
            }
            $Result.Add($Item)
        }
        foreach ($Item in $ToReAdd)
        {
            if (!$Result.Contains($Item))
            {
                $Result.Add($Item)
            }
        }
        foreach ($Item in $Ours)
        {
            if (!$Result.Contains($Item) -and !$BaselineSet.ContainsKey($Item))
            {
                $Result.Add($Item)
            }
        }

        return [pscustomobject]@{
            Conflict      = $false
            ConflictItems = @()
            Merged        = $Result.ToArray()
        }
    }
}
