<#
.SYNOPSIS
    Strips our unchanged contributions from a structured 'Merged' file that's no longer produced by any
    requested component, keeping manual and other components' content in place.
.DESCRIPTION
    Only the structured JSON files we know how to parse and reconstruct ('.vscode/extensions.json',
    '.vscode/settings.json', '.config/dotnet-tools.json' and 'pages/package.json') are handled here, using
    each file's recorded 'Baseline' and the same per-key/per-entry mergers used when the file is still being
    generated, with an empty set of contributions standing in for "this component no longer contributes
    anything". Anything else (marker files, '.editorconfig') is reported as 'Unrecognized' so the caller
    leaves it entirely alone, matching the previous behaviour.
    Returns a '[pscustomobject]' with an 'Action' of 'Unrecognized', 'NoChange' (nothing to strip), 'Delete'
    (only empty structure would remain) or 'Update' (with the new 'Content').
#>
function Remove-BrownserveMergedFileContribution
{
    [CmdletBinding()]
    param
    (
        # The absolute path to the file on disk
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        # The file's repository-relative path, as recorded in the manifest
        [Parameter(Mandatory = $true)]
        [string]
        $RelativePath,

        # The file's recorded manifest entry
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Recorded
    )
    process
    {
        if (!(Test-Path $Path))
        {
            return [pscustomobject]@{ Action = 'NoChange'; Content = $null }
        }

        $Leaf = Split-Path $Path -Leaf

        try
        {
            switch ($Leaf)
            {
                'extensions.json'
                {
                    $Disk = Get-Content -Path $Path -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                    $DiskRecommendations = @($Disk.recommendations)
                    $Baseline = @()
                    if ($Recorded.Baseline -and $Recorded.Baseline.recommendations)
                    {
                        $Baseline = @($Recorded.Baseline.recommendations)
                    }
                    $Result = Merge-BrownserveSetContribution -Disk $DiskRecommendations -Baseline $Baseline -Ours @() -ErrorAction 'Stop'
                    if (@(Compare-Object -ReferenceObject $DiskRecommendations -DifferenceObject $Result.Merged).Count -eq 0)
                    {
                        return [pscustomobject]@{ Action = 'NoChange'; Content = $null }
                    }
                    if ($Result.Merged.Count -eq 0)
                    {
                        return [pscustomobject]@{ Action = 'Delete'; Content = $null }
                    }
                    $Content = (@{ recommendations = $Result.Merged } | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent).Content
                    return [pscustomobject]@{ Action = 'Update'; Content = $Content }
                }
                'settings.json'
                {
                    $Disk = Get-Content -Path $Path -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                    $Baseline = @{}
                    if ($Recorded.Baseline)
                    {
                        $Baseline = $Recorded.Baseline
                    }
                    $Result = Merge-BrownserveKeyedContribution -Disk $Disk -Baseline $Baseline -Ours @{} -ErrorAction 'Stop'
                    if ($Result.Merged.Count -eq $Disk.Count)
                    {
                        return [pscustomobject]@{ Action = 'NoChange'; Content = $null }
                    }
                    if ($Result.Merged.Count -eq 0)
                    {
                        return [pscustomobject]@{ Action = 'Delete'; Content = $null }
                    }
                    $Sorted = ConvertTo-SortedHashtable $Result.Merged
                    $Content = ($Sorted | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent).Content
                    return [pscustomobject]@{ Action = 'Update'; Content = $Content }
                }
                'dotnet-tools.json'
                {
                    $Disk = Get-Content -Path $Path -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                    $DiskTools = @{}
                    if ($Disk.ContainsKey('tools'))
                    {
                        $DiskTools = $Disk.tools
                    }
                    $Baseline = @{}
                    if ($Recorded.Baseline)
                    {
                        $Baseline = $Recorded.Baseline
                    }
                    $Result = Merge-BrownserveKeyedContribution -Disk $DiskTools -Baseline $Baseline -Ours @{} -ErrorAction 'Stop'
                    if ($Result.Merged.Count -eq $DiskTools.Count)
                    {
                        return [pscustomobject]@{ Action = 'NoChange'; Content = $null }
                    }
                    if ($Result.Merged.Count -eq 0)
                    {
                        return [pscustomobject]@{ Action = 'Delete'; Content = $null }
                    }
                    $SortedTools = [ordered]@{}
                    foreach ($ToolName in ($Result.Merged.Keys | Sort-Object))
                    {
                        $SortedTools[$ToolName] = $Result.Merged[$ToolName]
                    }
                    $NewManifest = [ordered]@{
                        version = $Disk.version
                        isRoot  = $Disk.isRoot
                        tools   = $SortedTools
                    }
                    $Content = ($NewManifest | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent).Content
                    return [pscustomobject]@{ Action = 'Update'; Content = $Content }
                }
                'package.json'
                {
                    $Disk = Get-Content -Path $Path -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                    $DiskFlat = ConvertTo-BrownservePackageJsonFlatMap -PackageJson $Disk
                    $Baseline = @{}
                    if ($Recorded.Baseline)
                    {
                        $Baseline = $Recorded.Baseline
                    }
                    $Result = Merge-BrownserveKeyedContribution -Disk $DiskFlat -Baseline $Baseline -Ours @{} -ErrorAction 'Stop'
                    if ($Result.Merged.Count -eq $DiskFlat.Count)
                    {
                        return [pscustomobject]@{ Action = 'NoChange'; Content = $null }
                    }
                    if ($Result.Merged.Count -eq 0)
                    {
                        return [pscustomobject]@{ Action = 'Delete'; Content = $null }
                    }
                    $Merged = ConvertFrom-BrownservePackageJsonFlatMap -FlatMap $Result.Merged
                    $Content = ($Merged | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent).Content
                    return [pscustomobject]@{ Action = 'Update'; Content = $Content }
                }
                default
                {
                    return [pscustomobject]@{ Action = 'Unrecognized'; Content = $null }
                }
            }
        }
        catch
        {
            return [pscustomobject]@{ Action = 'Unrecognized'; Content = $null }
        }
    }
}
