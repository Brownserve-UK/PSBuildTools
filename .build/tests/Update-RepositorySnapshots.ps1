#Requires -Version 6.0
#Requires -Modules Pester
<#
.SYNOPSIS
    Regenerates the committed snapshots used by 'RepositorySnapshots.Tests.ps1'.
.DESCRIPTION
    Deletes every snapshot directory under '.build/snapshots/' and rewrites them from scratch by running 'RepositorySnapshots.Tests.ps1'
    with the BROWNSERVE_UPDATE_SNAPSHOTS environment variable set.
    This reuses the exact same fixtures and mocks as the tests themselves (both are defined in
    'RepositorySnapshotFixtures.ps1'), so the snapshots and the tests that verify them can never drift apart.
    Requires the module to already be built (run '.build/build.ps1 -Build Build' first, or any target that
    depends on it) since it imports the built module from '$global:BrownserveBuiltModuleDirectory' in the
    same way the Pester tests do.
.EXAMPLE
    ./.build/tests/Update-RepositorySnapshots.ps1
#>
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'

$SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
$TestFilePath = Join-Path $PSScriptRoot 'RepositorySnapshots.Tests.ps1'

if (Test-Path $SnapshotsRoot)
{
    Get-ChildItem -Path $SnapshotsRoot -Directory -Force | Remove-Item -Recurse -Force
}
else
{
    New-Item -Path $SnapshotsRoot -ItemType Directory -Force | Out-Null
}

$PreviousValue = $env:BROWNSERVE_UPDATE_SNAPSHOTS
try
{
    $env:BROWNSERVE_UPDATE_SNAPSHOTS = '1'
    $PesterConfig = New-PesterConfiguration
    $PesterConfig.Run.Path = $TestFilePath
    $PesterConfig.Run.PassThru = $true
    $PesterConfig.Output.Verbosity = 'Detailed'
    $Result = Invoke-Pester -Configuration $PesterConfig

    if ($Result.FailedCount -gt 0)
    {
        throw "$($Result.FailedCount) test(s) failed while regenerating snapshots, see output above."
    }
}
finally
{
    if ($null -eq $PreviousValue)
    {
        Remove-Item Env:\BROWNSERVE_UPDATE_SNAPSHOTS -ErrorAction SilentlyContinue
    }
    else
    {
        $env:BROWNSERVE_UPDATE_SNAPSHOTS = $PreviousValue
    }
}

Write-Host "Snapshots regenerated at '$SnapshotsRoot'." -ForegroundColor Green
