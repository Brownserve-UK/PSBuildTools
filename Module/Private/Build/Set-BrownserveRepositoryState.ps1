<#
.SYNOPSIS
    Applies a 'Compare-BrownserveRepository' result to disk safely, used by both 'Initialize-BrownserveRepository'
    and 'Update-BrownserveRepository'.
.DESCRIPTION
    This is the one place either cmdlet actually touches the filesystem. Before making any change it re-checks
    that there are no unresolved conflicts (unless '-Force' is passed). It then backs up every file it's about to
    modify or delete to a temporary directory, creates any missing directories, writes every missing/changed file
    and performs every removal, and only then writes '.brownserve_repository_manifest', last, since it's the
    record of everything that came before it.
    If anything fails partway through, every backed up file is restored, every file and directory this run
    created is removed, the manifest is left completely untouched, and the original error is rethrown.
#>
function Set-BrownserveRepositoryState
{
    [CmdletBinding()]
    param
    (
        # The path to the repository the state applies to
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryPath,

        # The result of 'Compare-BrownserveRepository' to apply
        [Parameter(Mandatory = $true)]
        [pscustomobject]
        $RepositoryState,

        # Overwrite conflicting content instead of stopping
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    process
    {
        if ($RepositoryState.ConflictedFiles.Count -gt 0 -and !$Force)
        {
            $ConflictSummary = ($RepositoryState.ConflictedFiles | ForEach-Object { "$($_.Path): $($_.Reason)" }) -join "`n"
            throw "The following files have been modified since they were last generated and would be overwritten:`n$ConflictSummary`nUse the '-Force' switch to overwrite them."
        }

        $ManifestPath = $RepositoryState.ManifestPath
        $FilesToWrite = @($RepositoryState.MissingFiles + $RepositoryState.ChangedFiles | Where-Object { $_.Path -ne $ManifestPath })
        $ManifestFile = @($RepositoryState.MissingFiles + $RepositoryState.ChangedFiles | Where-Object { $_.Path -eq $ManifestPath }) | Select-Object -First 1
        $FilesToDelete = @($RepositoryState.RemovedFiles | Where-Object { $_.Action -eq 'Removed' })

        if ($FilesToWrite.Count -eq 0 -and $FilesToDelete.Count -eq 0 -and !$ManifestFile)
        {
            Write-Verbose 'Repository does not require any changes.'
            return
        }

        try
        {
            $BackupDirectory = New-BrownserveTemporaryDirectory -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to create backup directory.`n$($_.Exception.Message)"
        }

        $Backups = @()
        $CreatedFiles = @()
        $CreatedDirectories = @()

        try
        {
            foreach ($Directory in $RepositoryState.MissingDirectories)
            {
                if (!(Test-Path $Directory.Path))
                {
                    Write-Verbose "Creating directory '$($Directory.Path)'"
                    New-Item -Path $Directory.Path -ItemType 'Directory' -ErrorAction 'Stop' | Out-Null
                    $CreatedDirectories += $Directory.Path
                }
            }

            foreach ($File in ($FilesToWrite + $FilesToDelete))
            {
                if (Test-Path $File.Path)
                {
                    $BackupPath = Join-Path $BackupDirectory ([guid]::NewGuid().ToString())
                    Copy-Item -Path $File.Path -Destination $BackupPath -ErrorAction 'Stop'
                    $Backups += [pscustomobject]@{ Path = $File.Path; BackupPath = $BackupPath }
                }
            }
            if ($ManifestFile -and (Test-Path $ManifestFile.Path))
            {
                $BackupPath = Join-Path $BackupDirectory ([guid]::NewGuid().ToString())
                Copy-Item -Path $ManifestFile.Path -Destination $BackupPath -ErrorAction 'Stop'
                $Backups += [pscustomobject]@{ Path = $ManifestFile.Path; BackupPath = $BackupPath }
            }

            foreach ($File in $FilesToWrite)
            {
                if (!(Test-Path $File.Path))
                {
                    Write-Verbose "Creating file '$($File.Path)'"
                    New-Item -Path $File.Path -ItemType 'File' -ErrorAction 'Stop' | Out-Null
                    $CreatedFiles += $File.Path
                }
                else
                {
                    Write-Verbose "Updating file '$($File.Path)'"
                }
                $File | Set-BrownserveContent -ErrorAction 'Stop'
            }

            foreach ($File in $FilesToDelete)
            {
                if (Test-Path $File.Path)
                {
                    Write-Verbose "Removing file '$($File.Path)'"
                    Remove-Item -Path $File.Path -Force -ErrorAction 'Stop'
                }
            }

            if ($ManifestFile)
            {
                if (!(Test-Path $ManifestFile.Path))
                {
                    New-Item -Path $ManifestFile.Path -ItemType 'File' -ErrorAction 'Stop' | Out-Null
                    $CreatedFiles += $ManifestFile.Path
                }
                Write-Verbose "Writing repository manifest '$ManifestPath'"
                $ManifestFile | Set-BrownserveContent -ErrorAction 'Stop'
            }
        }
        catch
        {
            $OriginalError = $_
            foreach ($Backup in $Backups)
            {
                Copy-Item -Path $Backup.BackupPath -Destination $Backup.Path -Force -ErrorAction 'SilentlyContinue'
            }
            foreach ($CreatedFile in $CreatedFiles)
            {
                Remove-Item -Path $CreatedFile -Force -ErrorAction 'SilentlyContinue'
            }
            foreach ($CreatedDirectory in ($CreatedDirectories | Sort-Object -Descending))
            {
                Remove-Item -Path $CreatedDirectory -Recurse -Force -ErrorAction 'SilentlyContinue'
            }
            Remove-Item -Path $BackupDirectory -Recurse -Force -ErrorAction 'SilentlyContinue'
            throw $OriginalError
        }

        Remove-Item -Path $BackupDirectory -Recurse -Force -ErrorAction 'SilentlyContinue'
    }
}
