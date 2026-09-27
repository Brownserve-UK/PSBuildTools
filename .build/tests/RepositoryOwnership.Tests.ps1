#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

Describe 'Compare-BrownserveRepository file ownership' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

        Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
        Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

        function script:Publish-BrownserveCompareResult
        {
            param
            (
                [Parameter(Mandatory = $true)]
                $Result
            )

            foreach ($Directory in $Result.MissingDirectories)
            {
                if (!(Test-Path $Directory.Path))
                {
                    New-Item -Path $Directory.Path -ItemType Directory -Force | Out-Null
                }
            }
            foreach ($File in ($Result.MissingFiles + $Result.ChangedFiles))
            {
                $ParentDirectory = Split-Path $File.Path -Parent
                if (!(Test-Path $ParentDirectory))
                {
                    New-Item -Path $ParentDirectory -ItemType Directory -Force | Out-Null
                }
                if (!(Test-Path $File.Path))
                {
                    New-Item -Path $File.Path -ItemType File -Force | Out-Null
                }
                $File | Set-BrownserveContent -ErrorAction 'Stop'
            }
        }

        function script:Invoke-BrownserveCompare
        {
            param
            (
                [Parameter(Mandatory = $true)]
                [string]
                $RepositoryPath,

                [switch]
                $Force
            )

            InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $RepositoryPath; Force = [bool]$Force } {
                param($RepositoryPath, $Force)
                Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -Force:$Force -ErrorAction 'Stop'
            }
        }
    }

    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        Set-RepositorySnapshotMocks
    }

    It 'is idempotent: a second run against an unchanged repository has nothing to do' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath

        $Second.MissingFiles.Count | Should -Be 0
        $Second.ChangedFiles.Count | Should -Be 0
        $Second.ConflictedFiles.Count | Should -Be 0
    }

    It 'conflicts on a manual edit to a Managed file, and -Force replaces it' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $NugetConfigPath = Join-Path $script:RepositoryPath 'nuget.config'
        Add-Content -Path $NugetConfigPath -Value '<!-- manual edit -->'

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Contain $NugetConfigPath
        $Second.ChangedFiles.Path | Should -Not -Contain $NugetConfigPath

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        $Forced.ConflictedFiles.Count | Should -Be 0
        $Forced.ChangedFiles.Path | Should -Contain $NugetConfigPath
    }

    It 'never overwrites a Seeded file, and recreates it if it is deleted' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ToolsPath = Join-Path (Join-Path $script:RepositoryPath '.config') 'dotnet-tools.json'
        Set-Content -Path $ToolsPath -Value '{"manual":true}' -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ChangedFiles.Path | Should -Not -Contain $ToolsPath
        $Second.ConflictedFiles.Path | Should -Not -Contain $ToolsPath

        Remove-Item -Path $ToolsPath -Force
        $Third = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Third.MissingFiles.Path | Should -Contain $ToolsPath
    }

    It 'establishes a baseline without conflicts from a v2 manifest that has no Files map' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
        $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $Manifest.Remove('Files')
        ($Manifest | ConvertTo-Json -Depth 100) | Set-Content -Path $ManifestPath -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Count | Should -Be 0

        Publish-BrownserveCompareResult -Result $Second
        $ManifestAfter = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ManifestAfter.Files.Count | Should -BeGreaterThan 0
    }
}
