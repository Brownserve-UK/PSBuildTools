<#
.SYNOPSIS
    Compares a set of generated '[BrownserveManagedFile]' objects against disk and against the previous
    repository manifest, working out what's missing, changed, conflicted or safe to remove.
.DESCRIPTION
    This is the one place 'Compare-BrownserveRepository' hands off to once it's finished generating content for
    every file the requested components produce. For each file:
      - 'Seeded' files are only ever created, never compared or overwritten once they exist.
      - 'Managed' and 'Merged' files are compared whole-file against disk. A 'Managed' file whose disk hash differs
        from both the previously recorded hash and the newly generated content is a conflict unless '-Force' is
        passed. 'Merged' files are never conflict-checked here, their generation already merges manual content in
        (marker sections, structured keys), so whatever they generate is what gets written.
    Once every generated file has been classified, any path recorded in the previous manifest's 'Files' map that
    the current set of components no longer produces is handled as a removal:
      - 'Managed': removed if its disk hash still matches the recorded hash. A modified file is a conflict unless
        '-Force' is passed, in which case it's removed anyway.
      - 'Seeded': left alone on disk, its manifest entry is simply dropped.
      - 'Merged': left alone on disk and its manifest entry is carried forward unchanged, because removing our
        contribution from a merged file is a later piece of work.
#>
function Compare-BrownserveManagedFile
{
    [CmdletBinding()]
    param
    (
        # The repository root, used to resolve manifest-relative paths
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryPath,

        # Every file the currently requested components produce
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [BrownserveManagedFile[]]
        $ManagedFile,

        # The previous manifest's 'Files' map, keyed by repository-relative path
        [Parameter(Mandatory = $false)]
        [hashtable]
        $CurrentManifestFiles = @{},

        # Overwrite conflicting content instead of reporting it
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    process
    {
        $MissingFiles = @()
        $ChangedFiles = @()
        $ConflictedFiles = @()
        $RemovedFiles = @()
        $FilesMap = [ordered]@{}

        foreach ($File in $ManagedFile)
        {
            $RelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $File.Path) -replace '\\', '/'
            $Exists = Test-Path $File.Path

            if ($File.Ownership -eq [BrownserveFileOwnership]::Seeded)
            {
                if (!$Exists)
                {
                    $MissingFiles += [pscustomobject]@{
                        Path       = $File.Path
                        Content    = $File.Content
                        LineEnding = $File.LineEnding
                    }
                }
                $FilesMap[$RelativePath] = [ordered]@{
                    Ownership = $File.Ownership.ToString()
                    Component = $File.Component
                }
                continue
            }

            $NewHash = Get-BrownserveManagedFileHash -Content $File.Content
            $Record = [ordered]@{
                Ownership = $File.Ownership.ToString()
                Component = $File.Component
                Hash      = $NewHash
            }

            if (!$Exists)
            {
                $MissingFiles += [pscustomobject]@{
                    Path       = $File.Path
                    Content    = $File.Content
                    LineEnding = $File.LineEnding
                }
                $FilesMap[$RelativePath] = $Record
                continue
            }

            $DiskContent = (Get-BrownserveContent -Path $File.Path -ErrorAction 'Stop').Content
            $Difference = Compare-Object `
                -ReferenceObject $DiskContent `
                -DifferenceObject $File.Content `
                -SyncWindow 1 `
                -ErrorAction 'Stop'

            if ($Difference)
            {
                $IsConflict = $false
                if ($File.Ownership -eq [BrownserveFileOwnership]::Managed -and $CurrentManifestFiles.ContainsKey($RelativePath))
                {
                    $Recorded = $CurrentManifestFiles[$RelativePath]
                    if ($Recorded.Ownership -eq 'Managed' -and $Recorded.Hash)
                    {
                        $DiskHash = Get-BrownserveManagedFileHash -Content $DiskContent
                        if (($DiskHash -ne $Recorded.Hash) -and ($DiskHash -ne $NewHash))
                        {
                            $IsConflict = $true
                        }
                    }
                }

                if ($IsConflict -and !$Force)
                {
                    $ConflictedFiles += [pscustomobject]@{
                        Path   = $File.Path
                        Reason = 'The file has been modified since it was last generated and would be overwritten.'
                    }
                    $Record['Hash'] = $Recorded.Hash
                }
                else
                {
                    $ChangedFiles += [pscustomobject]@{
                        Path       = $File.Path
                        Content    = $File.Content
                        LineEnding = $File.LineEnding
                    }
                }
            }

            $FilesMap[$RelativePath] = $Record
        }

        foreach ($Key in $CurrentManifestFiles.Keys)
        {
            if ($FilesMap.Contains($Key))
            {
                continue
            }

            $Recorded = $CurrentManifestFiles[$Key]
            $AbsolutePath = Join-Path $RepositoryPath ($Key -replace '/', [System.IO.Path]::DirectorySeparatorChar)

            switch ($Recorded.Ownership)
            {
                'Seeded'
                {
                    $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Skipped (Seeded)' }
                }
                'Merged'
                {
                    $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'merged contributions not removed' }
                    $FilesMap[$Key] = $Recorded
                }
                default
                {
                    if (!(Test-Path $AbsolutePath))
                    {
                        $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Removed' }
                        continue
                    }
                    $DiskContent = (Get-BrownserveContent -Path $AbsolutePath -ErrorAction 'Stop').Content
                    $DiskHash = Get-BrownserveManagedFileHash -Content $DiskContent
                    if (($DiskHash -eq $Recorded.Hash) -or $Force)
                    {
                        $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Removed' }
                    }
                    else
                    {
                        $ConflictedFiles += [pscustomobject]@{
                            Path   = $AbsolutePath
                            Reason = 'The file is no longer produced by the requested components but has been modified since it was last generated.'
                        }
                        $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Conflict' }
                    }
                }
            }
        }

        return [pscustomobject]@{
            MissingFiles    = $MissingFiles
            ChangedFiles    = $ChangedFiles
            ConflictedFiles = $ConflictedFiles
            RemovedFiles    = $RemovedFiles
            Files           = $FilesMap
        }
    }
}
