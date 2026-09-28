<#
.SYNOPSIS
    Compares a set of generated '[BrownserveManagedFile]' objects against disk and against the previous
    repository manifest, working out what's missing, changed, conflicted or safe to remove.
.DESCRIPTION
    This is the one place 'Compare-BrownserveRepository' hands off to once it's finished generating content for
    every file the requested components produce. For each file:
      - 'Seeded' files are only ever created, never compared or overwritten once they exist.
      - 'Managed' files are compared whole-file against disk. A disk hash that differs from both the
        previously recorded hash and the newly generated content is a conflict unless '-Force' is passed.
      - 'Merged' files have already had their marker-section or structured-key conflicts resolved by
        'Compare-BrownserveRepository' (which has the marker/structure knowledge and the '-Force' switch to
        hand to each merger), and simply arrive here with '$File.Conflict' set when an unresolved conflict
        remains. When it's not set, the file's 'Content' is written like any other, and the manifest 'Hash' is
        taken from 'MarkerSection.Generated' (a marker file's generated section only) when present, or from
        the whole file otherwise. 'StructuredContributions', when present, is recorded as the file's 'Baseline'.
    Once every generated file has been classified, any path recorded in the previous manifest's 'Files' map that
    the current set of components no longer produces is handled as a removal:
      - 'Managed': removed if its disk hash still matches the recorded hash. A modified file is a conflict unless
        '-Force' is passed, in which case it's removed anyway.
      - 'Seeded': left alone on disk, its manifest entry is simply dropped.
      - 'Merged': our unchanged contributions are stripped from the file using its recorded 'Baseline', leaving
        manual content and content added by other components in place. If nothing is left but empty structure,
        the file is deleted. File types this cmdlet doesn't recognise are left entirely alone, matching before.
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

            if ($File.Conflict)
            {
                $ConflictedFiles += [pscustomobject]@{
                    Path   = $File.Path
                    Reason = $File.ConflictReason
                }
                if ($CurrentManifestFiles.ContainsKey($RelativePath))
                {
                    $FilesMap[$RelativePath] = $CurrentManifestFiles[$RelativePath]
                }
                continue
            }

            if ($File.MarkerSection -and $File.MarkerSection.ContainsKey('Generated'))
            {
                $NewHash = Get-BrownserveManagedFileHash -Content $File.MarkerSection.Generated
            }
            else
            {
                $NewHash = Get-BrownserveManagedFileHash -Content $File.Content
            }
            $Record = [ordered]@{
                Ownership = $File.Ownership.ToString()
                Component = $File.Component
                Hash      = $NewHash
            }
            if ($File.StructuredContributions)
            {
                $Record['Baseline'] = $File.StructuredContributions
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
                    $RemovalResult = Remove-BrownserveMergedFileContribution `
                        -Path $AbsolutePath `
                        -RelativePath $Key `
                        -Recorded $Recorded `
                        -ErrorAction 'Stop'
                    switch ($RemovalResult.Action)
                    {
                        'Unrecognized'
                        {
                            $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'merged contributions not removed' }
                            $FilesMap[$Key] = $Recorded
                        }
                        'NoChange'
                        {
                            $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'merged contributions already removed' }
                        }
                        'Delete'
                        {
                            $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Removed' }
                        }
                        'Update'
                        {
                            $RemovedFiles += [pscustomobject]@{ Path = $AbsolutePath; Action = 'Stripped' }
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $AbsolutePath
                                Content    = $RemovalResult.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
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
