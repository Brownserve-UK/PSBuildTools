<#
.SYNOPSIS
    Merges our generated contributions into a structured 'Merged' file, keyed by an arbitrary string key.
.DESCRIPTION
    Used for every structured 'Merged' file that boils down to "a dictionary of keys we may or may not
    contribute to" ('.vscode/settings.json' top level keys, '.config/dotnet-tools.json' tool names,
    'pages/package.json' dependency/script names and '.editorconfig' section+property pairs).
    For each key we contribute ('Ours'): if the disk value is missing, or equals the previously recorded
    baseline value, or already equals our new value, we write our value. If the disk value differs from
    both the baseline and our new value that's a conflict, unless '-Force' is passed, in which case our
    value wins.
    For each key we no longer contribute (present in 'Baseline' but not 'Ours'): if the disk value still
    matches the baseline it's removed, otherwise the user has changed it and it's left alone (not a
    conflict).
    Every other key present on disk, that we've never contributed, is always kept untouched.
#>
function Merge-BrownserveKeyedContribution
{
    [CmdletBinding()]
    param
    (
        # The current on-disk key/value pairs
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Disk = @{},

        # The key/value pairs we contributed the last time this file was generated
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Baseline = @{},

        # The key/value pairs we contribute this time
        [Parameter(Mandatory = $false)]
        [hashtable]
        $Ours = @{},

        # Resolve conflicts in favour of our contributed value instead of reporting them
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    process
    {
        $ConflictKeys = @()
        $Merged = [ordered]@{}
        foreach ($Key in ($Disk.Keys | Sort-Object))
        {
            $Merged[$Key] = $Disk[$Key]
        }

        foreach ($Key in ($Ours.Keys | Sort-Object))
        {
            $OursValue = $Ours[$Key]
            if (!$Disk.ContainsKey($Key))
            {
                $Merged[$Key] = $OursValue
                continue
            }

            $DiskValue = $Disk[$Key]
            if (Test-BrownserveValueEqual -ReferenceValue $DiskValue -DifferenceValue $OursValue)
            {
                $Merged[$Key] = $OursValue
                continue
            }

            $HasBaseline = $Baseline.ContainsKey($Key)
            $EqualsBaseline = $HasBaseline -and (Test-BrownserveValueEqual -ReferenceValue $DiskValue -DifferenceValue $Baseline[$Key])
            if (!$HasBaseline -or $EqualsBaseline)
            {
                $Merged[$Key] = $OursValue
                continue
            }

            if ($Force)
            {
                $Merged[$Key] = $OursValue
            }
            else
            {
                $ConflictKeys += $Key
            }
        }

        if ($ConflictKeys.Count -gt 0 -and !$Force)
        {
            return [pscustomobject]@{
                Conflict     = $true
                ConflictKeys = $ConflictKeys
                Merged       = $null
            }
        }

        foreach ($Key in $Baseline.Keys)
        {
            if ($Ours.ContainsKey($Key))
            {
                continue
            }
            if ($Merged.Contains($Key) -and (Test-BrownserveValueEqual -ReferenceValue $Merged[$Key] -DifferenceValue $Baseline[$Key]))
            {
                $Merged.Remove($Key)
            }
        }

        return [pscustomobject]@{
            Conflict     = $false
            ConflictKeys = @()
            Merged       = $Merged
        }
    }
}
