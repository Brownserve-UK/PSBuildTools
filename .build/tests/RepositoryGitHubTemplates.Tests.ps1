#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

Describe 'CONTRIBUTING and pull request templates' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

        Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
        Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

        $script:SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'

        function script:Publish-TemplateCompareResult
        {
            param ($Result)

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

        function script:Invoke-TemplateCompare
        {
            param
            (
                [string]
                $RepositoryPath,

                [string[]]
                $Components = @(),

                [hashtable]
                $ComponentOptions = @{},

                [hashtable]
                $ModuleInfoData,

                [string]
                $RepoName = 'test-repo'
            )

            InModuleScope Brownserve.PSBuildTools -Parameters @{
                RepositoryPath   = $RepositoryPath
                Components       = $Components
                ComponentOptions = $ComponentOptions
                ModuleInfoData   = $ModuleInfoData
                RepoName         = $RepoName
            } {
                param($RepositoryPath, $Components, $ComponentOptions, $ModuleInfoData, $RepoName)
                if ($ModuleInfoData)
                {
                    $ComponentOptions['PowerShellModule'] = @{ ModuleInfo = [BrownservePowerShellModule]$ModuleInfoData }
                }
                Compare-BrownserveRepository `
                    -RepositoryPath $RepositoryPath `
                    -Components $Components `
                    -ComponentOptions $ComponentOptions `
                    -RepoName $RepoName `
                    -ErrorAction 'Stop'
            }
        }

        function script:Get-TemplateManifest
        {
            param ($Result)

            $Entry = ($Result.ChangedFiles + $Result.MissingFiles) | Where-Object { $_.Path -eq $Result.ManifestPath } | Select-Object -First 1
            if (!$Entry)
            {
                return $null
            }
            return ($Entry.Content -join "`n") | ConvertFrom-Json -Depth 100 -AsHashtable
        }

        function script:Assert-TemplatesUntouched
        {
            param ($Result, $ContributingPath, $PRTemplatePath)

            foreach ($Path in @($ContributingPath, $PRTemplatePath))
            {
                $Result.MissingFiles.Path | Should -Not -Contain $Path
                $Result.ChangedFiles.Path | Should -Not -Contain $Path
                $Result.ConflictedFiles.Path | Should -Not -Contain $Path
                @($Result.RemovedFiles | Where-Object { $_.Path -eq $Path }).Count | Should -Be 0
            }
            $Manifest = Get-TemplateManifest -Result $Result
            $Manifest.Files['.github/CONTRIBUTING.md'].Ownership | Should -Be 'Seeded'
            $Manifest.Files['.github/pull_request_template.md'].Ownership | Should -Be 'Seeded'
        }
    }

    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        $script:ContributingPath = Join-Path $script:RepositoryPath '.github' 'CONTRIBUTING.md'
        $script:PRTemplatePath = Join-Path $script:RepositoryPath '.github' 'pull_request_template.md'
        Set-RepositorySnapshotMocks
    }

    Context 'PowerShell module repositories' {
        BeforeEach {
            $script:ModuleInfoData = @{ Name = 'Brownserve.TestModule'; Description = 'A test module used for repository snapshot testing.'; GUID = '11111111-1111-1111-1111-111111111111'; Tags = @('test', 'powershell') }
        }

        It 'renders Managed files identical to the PowerShellModule snapshot' {
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $script:ModuleInfoData -RepoName 'test-powershell-module'
            foreach ($Name in @('CONTRIBUTING.md', 'pull_request_template.md'))
            {
                $Rendered = ($Result.MissingFiles | Where-Object { $_.Path -eq (Join-Path $script:RepositoryPath '.github' $Name) }).Content -join "`n"
                $Expected = Get-Content -Path (Join-Path $script:SnapshotsRoot 'PowerShellModule' '.github' $Name) -Raw
                $Rendered | Should -BeExactly $Expected
            }
            $Manifest = Get-TemplateManifest -Result $Result
            $Manifest.Files['.github/CONTRIBUTING.md'].Ownership | Should -Be 'Managed'
            $Manifest.Files['.github/pull_request_template.md'].Ownership | Should -Be 'Managed'
        }

        It 'uses the PowerShell module wording rather than the generic seed' {
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $script:ModuleInfoData
            ($Result.MissingFiles | Where-Object { $_.Path -eq $script:ContributingPath }).Content -join "`n" | Should -Match 'PowerShell style guidelines'
            ($Result.MissingFiles | Where-Object { $_.Path -eq $script:PRTemplatePath }).Content -join "`n" | Should -Match 'Brownserve\.TestModule'
        }

        It 'conflicts on a hand-edited Managed CONTRIBUTING' {
            Publish-TemplateCompareResult -Result (Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $script:ModuleInfoData)
            Add-Content -Path $script:ContributingPath -Value 'A manual edit.'
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $script:ModuleInfoData
            $Result.ConflictedFiles.Path | Should -Contain $script:ContributingPath
        }
    }

    Context 'generic seeded templates' {
        It 'gives a RustBinary repository both seeds' {
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            $Result.MissingFiles.Path | Should -Contain $script:ContributingPath
            $Result.MissingFiles.Path | Should -Contain $script:PRTemplatePath
            $Contributing = ($Result.MissingFiles | Where-Object { $_.Path -eq $script:ContributingPath }).Content -join "`n"
            $Contributing | Should -Match '^# Contributing'
            $Contributing | Should -Match 'pwsh \./\.build/build\.ps1 -Build BuildTestAndCheck'
            $Contributing | Should -Match 'feat!: remove a deprecated option'
            $Contributing | Should -Not -Match 'A second check will block merge'
            $PRTemplate = ($Result.MissingFiles | Where-Object { $_.Path -eq $script:PRTemplatePath }).Content -join "`n"
            $PRTemplate | Should -Match 'submitting a PR to test-repo!'
            $PRTemplate | Should -Match 'https://github\.com/Brownserve-UK/test-repo/blob/main/\.github/CONTRIBUTING\.md'
            $PRTemplate | Should -Not -Match '###'
            $Manifest = Get-TemplateManifest -Result $Result
            $Manifest.Files['.github/CONTRIBUTING.md'].Ownership | Should -Be 'Seeded'
            $Manifest.Files['.github/pull_request_template.md'].Ownership | Should -Be 'Seeded'
        }

        It 'gives a NuGetPackage repository both seeds' {
            $Options = @{ NuGetPackage = @{ PackageId = 'Brownserve.TestPackage'; PackageDescription = 'A test package' } }
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('NuGetPackage') -ComponentOptions $Options
            $Result.MissingFiles.Path | Should -Contain $script:ContributingPath
            $Result.MissingFiles.Path | Should -Contain $script:PRTemplatePath
        }

        It 'gives a Core only repository neither file' {
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath
            $Result.MissingFiles.Path | Should -Not -Contain $script:ContributingPath
            $Result.MissingFiles.Path | Should -Not -Contain $script:PRTemplatePath
            $Manifest = Get-TemplateManifest -Result $Result
            $Manifest.Files.ContainsKey('.github/CONTRIBUTING.md') | Should -BeFalse
            $Manifest.Files.ContainsKey('.github/pull_request_template.md') | Should -BeFalse
        }

        It 'recreates a seed that has been deleted' {
            Publish-TemplateCompareResult -Result (Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary'))
            Remove-Item -Path $script:ContributingPath
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            $Result.MissingFiles.Path | Should -Contain $script:ContributingPath
        }

        It 'is idempotent' {
            Publish-TemplateCompareResult -Result (Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary'))
            $Second = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            $Second.MissingFiles.Count | Should -Be 0
            $Second.ChangedFiles.Count | Should -Be 0
            $Second.ConflictedFiles.Count | Should -Be 0
        }
    }

    Context 'existing files in a RustBinary repository' {
        BeforeEach {
            $script:HandEdited = "# Our own contributing guide`n`nWritten by hand.`n"
        }

        It 'keeps files a previous manifest recorded as Managed byte for byte and records them as Seeded' {
            Publish-TemplateCompareResult -Result (Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary'))
            [System.IO.File]::WriteAllText($script:ContributingPath, $script:HandEdited)
            $Before = (Get-FileHash -Path $script:ContributingPath).Hash
            $PRBefore = (Get-FileHash -Path $script:PRTemplatePath).Hash

            $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
            $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
            $Manifest.Files['.github/CONTRIBUTING.md'] = [ordered]@{ Ownership = 'Managed'; Component = 'ReleaseLifecycle'; Hash = 'sha256:0000000000000000000000000000000000000000000000000000000000000000' }
            $Manifest.Files['.github/pull_request_template.md'] = [ordered]@{ Ownership = 'Managed'; Component = 'ReleaseLifecycle'; Hash = 'sha256:1111111111111111111111111111111111111111111111111111111111111111' }
            ($Manifest | ConvertTo-Json -Depth 100) | Set-Content -Path $ManifestPath -NoNewline

            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            Assert-TemplatesUntouched -Result $Result -ContributingPath $script:ContributingPath -PRTemplatePath $script:PRTemplatePath
            Publish-TemplateCompareResult -Result $Result

            (Get-FileHash -Path $script:ContributingPath).Hash | Should -Be $Before
            (Get-FileHash -Path $script:PRTemplatePath).Hash | Should -Be $PRBefore
            [System.IO.File]::ReadAllText($script:ContributingPath) | Should -BeExactly $script:HandEdited

            $Second = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            $Second.MissingFiles.Count | Should -Be 0
            $Second.ChangedFiles.Count | Should -Be 0
            $Second.ConflictedFiles.Count | Should -Be 0
        }

        It 'keeps files in a migrated v1 repository byte for byte and records them as Seeded' {
            Publish-TemplateCompareResult -Result (Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary'))
            [System.IO.File]::WriteAllText($script:ContributingPath, $script:HandEdited)
            $Before = (Get-FileHash -Path $script:ContributingPath).Hash

            $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
            (@{ ManifestVersion = '1.0.0'; RepositoryType = 'RustApp' } | ConvertTo-Json) | Set-Content -Path $ManifestPath -NoNewline

            $Migrated = InModuleScope Brownserve.PSBuildTools {
                ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType ([BrownserveRepoProjectType]::RustApp)
            }
            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components $Migrated.Components -ComponentOptions $Migrated.ComponentOptions
            Assert-TemplatesUntouched -Result $Result -ContributingPath $script:ContributingPath -PRTemplatePath $script:PRTemplatePath
            Publish-TemplateCompareResult -Result $Result

            (Get-FileHash -Path $script:ContributingPath).Hash | Should -Be $Before

            $Second = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components $Migrated.Components -ComponentOptions $Migrated.ComponentOptions
            $Second.MissingFiles.Count | Should -Be 0
            $Second.ChangedFiles.Count | Should -Be 0
            $Second.ConflictedFiles.Count | Should -Be 0
        }

        It 'keeps files the manifest never recorded byte for byte and records them as Seeded' {
            New-Item -Path (Join-Path $script:RepositoryPath '.github') -ItemType Directory -Force | Out-Null
            [System.IO.File]::WriteAllText($script:ContributingPath, $script:HandEdited)
            [System.IO.File]::WriteAllText($script:PRTemplatePath, "Hand written.`n")
            $Before = (Get-FileHash -Path $script:ContributingPath).Hash

            $Result = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            Assert-TemplatesUntouched -Result $Result -ContributingPath $script:ContributingPath -PRTemplatePath $script:PRTemplatePath
            Publish-TemplateCompareResult -Result $Result

            (Get-FileHash -Path $script:ContributingPath).Hash | Should -Be $Before
            [System.IO.File]::ReadAllText($script:PRTemplatePath) | Should -BeExactly "Hand written.`n"

            $Second = Invoke-TemplateCompare -RepositoryPath $script:RepositoryPath -Components @('RustBinary')
            $Second.MissingFiles.Count | Should -Be 0
            $Second.ChangedFiles.Count | Should -Be 0
            $Second.ConflictedFiles.Count | Should -Be 0
        }
    }
}
