#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

BeforeAll {
    . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

    $script:SnapshotsRoot = Join-Path $PSScriptRoot 'snapshots'
    $script:UpdateSnapshots = $env:BROWNSERVE_UPDATE_SNAPSHOTS -eq '1'
}

Describe 'Compare-BrownserveRepository snapshots' -ForEach (Get-RepositorySnapshotFixtures) {
    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive $CaseName
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        Set-RepositorySnapshotMocks
    }

    It "renders the expected repository state for '<CaseName>'" {
        $Result = Invoke-RepositorySnapshotCompare `
            -RepositoryPath $script:RepositoryPath `
            -ProjectType $ProjectType `
            -RepoName $RepoName `
            -Owner $Owner `
            -ModuleInfo $ModuleInfo

        $Result.ChangedFiles.Count | Should -Be 0 -Because 'the target repository is empty so nothing should be reported as changed'

        $ActualFiles = @{}
        foreach ($File in $Result.MissingFiles)
        {
            $RelativePath = Get-RepositorySnapshotRelativePath -BasePath $script:RepositoryPath -Path $File.Path
            $ActualFiles[$RelativePath] = ($File.Content -join "`n")
        }
        $ActualDirectories = @(
            $Result.MissingDirectories |
                ForEach-Object { Get-RepositorySnapshotRelativePath -BasePath $script:RepositoryPath -Path $_.Path } |
                Sort-Object
        )

        $CaseSnapshotDir = Join-Path $script:SnapshotsRoot $CaseName
        $DirectoriesManifestPath = Join-Path $CaseSnapshotDir '_MissingDirectories.txt'

        if ($script:UpdateSnapshots)
        {
            if (Test-Path $CaseSnapshotDir)
            {
                Remove-Item $CaseSnapshotDir -Recurse -Force
            }
            New-Item -Path $CaseSnapshotDir -ItemType Directory -Force | Out-Null
            foreach ($RelativePath in $ActualFiles.Keys)
            {
                $DestPath = Join-Path $CaseSnapshotDir $RelativePath
                $DestDir = Split-Path $DestPath -Parent
                if (!(Test-Path $DestDir))
                {
                    New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
                }
                $ContentToWrite = $ActualFiles[$RelativePath]
                if ($RelativePath -eq '.brownserve_repository_manifest')
                {
                    $ManifestData = $ContentToWrite | ConvertFrom-Json -AsHashtable
                    $OrderedManifest = [ordered]@{
                        RepositoryType  = $ManifestData.RepositoryType
                        ManifestVersion = $ManifestData.ManifestVersion
                    }
                    $ContentToWrite = (($OrderedManifest | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
                }
                [System.IO.File]::WriteAllText($DestPath, $ContentToWrite, [System.Text.UTF8Encoding]::new($false))
            }
            [System.IO.File]::WriteAllText($DirectoriesManifestPath, (($ActualDirectories -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

            Set-ItResult -Skipped -Because 'BROWNSERVE_UPDATE_SNAPSHOTS is set, snapshots have been (re)written rather than verified'
            return
        }

        if (!(Test-Path $CaseSnapshotDir))
        {
            throw "No snapshot directory found at '$CaseSnapshotDir'. Run 'Update-RepositorySnapshots.ps1' to generate one."
        }

        $ExpectedFileSet = @(
            Get-ChildItem -Path $CaseSnapshotDir -File -Recurse -Force |
                Where-Object { $_.Name -ne '_MissingDirectories.txt' } |
                ForEach-Object { Get-RepositorySnapshotRelativePath -BasePath $CaseSnapshotDir -Path $_.FullName } |
                Sort-Object
        )
        $ActualFileSet = @($ActualFiles.Keys | Sort-Object)

        $MissingFromActual = @($ExpectedFileSet | Where-Object { $ActualFileSet -notcontains $_ })
        $UnexpectedInActual = @($ActualFileSet | Where-Object { $ExpectedFileSet -notcontains $_ })

        $MissingFromActual | Should -BeNullOrEmpty -Because "these files are in the '$CaseName' snapshot but were not rendered by Compare-BrownserveRepository"
        $UnexpectedInActual | Should -BeNullOrEmpty -Because "these files were rendered by Compare-BrownserveRepository for '$CaseName' but have no committed snapshot"

        foreach ($RelativePath in $ExpectedFileSet)
        {
            $ExpectedContent = Get-Content -Path (Join-Path $CaseSnapshotDir $RelativePath) -Raw -ErrorAction Stop
            if ($null -eq $ExpectedContent)
            {
                $ExpectedContent = ''
            }
            $ActualContent = $ActualFiles[$RelativePath]

            if (($RelativePath -eq '.brownserve_repository_manifest') -and ($ExpectedContent -ne $ActualContent))
            {
                $ExpectedManifest = $ExpectedContent | ConvertFrom-Json -AsHashtable
                $ActualManifest = $ActualContent | ConvertFrom-Json -AsHashtable
                $ManifestKeysMatch = @(Compare-Object $ExpectedManifest.Keys $ActualManifest.Keys).Count -eq 0
                $ManifestValuesMatch = $ManifestKeysMatch -and -not ($ExpectedManifest.Keys | Where-Object { $ExpectedManifest[$_] -ne $ActualManifest[$_] })
                if ($ManifestValuesMatch)
                {
                    continue
                }
            }

            if ($ExpectedContent -ne $ActualContent)
            {
                $ExpectedLines = $ExpectedContent -split "`n"
                $ActualLines = $ActualContent -split "`n"
                $FirstDiffIndex = 0
                $MaxLines = [Math]::Max($ExpectedLines.Count, $ActualLines.Count)
                for ($i = 0; $i -lt $MaxLines; $i++)
                {
                    if ($ExpectedLines[$i] -ne $ActualLines[$i])
                    {
                        $FirstDiffIndex = $i
                        break
                    }
                }
                $ExpectedLine = if ($FirstDiffIndex -lt $ExpectedLines.Count) { $ExpectedLines[$FirstDiffIndex] } else { '<missing line>' }
                $ActualLine = if ($FirstDiffIndex -lt $ActualLines.Count) { $ActualLines[$FirstDiffIndex] } else { '<missing line>' }
                throw "Snapshot mismatch for project type '$CaseName', file '$RelativePath' at line $($FirstDiffIndex + 1):`nExpected: $ExpectedLine`nActual:   $ActualLine"
            }
        }

        $ExpectedDirectories = @()
        if (Test-Path $DirectoriesManifestPath)
        {
            $ExpectedDirectories = @(Get-Content -Path $DirectoriesManifestPath | Where-Object { $_ -ne '' })
        }
        $ActualDirectories | Should -Be $ExpectedDirectories -Because "the set of missing directories for '$CaseName' should match the snapshot"
    }
}
