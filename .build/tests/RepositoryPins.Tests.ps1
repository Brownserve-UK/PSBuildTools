#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

BeforeAll {
    . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
}

Describe 'New-PaketDependenciesFile pins' {
    It 'renders a bare version when no version is set' {
        InModuleScope Brownserve.PSBuildTools {
            $Rule = [PaketDependencyRule]@{ Source = 'nuget'; PackageName = 'Invoke-Build' }
            $Dependency = [PaketDependency]@{ Rule = @($Rule) }
            $Result = New-PaketDependenciesFile -PaketDependencies @($Dependency)
            $Result.Content -join "`n" | Should -Match 'nuget Invoke-Build(?!\s*=)'
        }
    }

    It 'renders an exact pin when a version without a prerelease label is set' {
        InModuleScope Brownserve.PSBuildTools {
            $Rule = [PaketDependencyRule]@{ Source = 'nuget'; PackageName = 'Brownserve.PSCommon'; Version = '1.2.3' }
            $Dependency = [PaketDependency]@{ Rule = @($Rule) }
            $Result = New-PaketDependenciesFile -PaketDependencies @($Dependency)
            $Result.Content -join "`n" | Should -Match ([regex]::Escape('nuget Brownserve.PSCommon = 1.2.3'))
        }
    }

    It 'renders an exact pin when a version with a prerelease label is set' {
        InModuleScope Brownserve.PSBuildTools {
            $Rule = [PaketDependencyRule]@{ Source = 'nuget'; PackageName = 'Brownserve.PSCommon'; Version = '1.2.3-beta1' }
            $Dependency = [PaketDependency]@{ Rule = @($Rule) }
            $Result = New-PaketDependenciesFile -PaketDependencies @($Dependency)
            $Result.Content -join "`n" | Should -Match ([regex]::Escape('nuget Brownserve.PSCommon = 1.2.3-beta1'))
        }
    }
}

Describe 'Get-BrownserveLoadedModuleVersion' {
    It 'throws when the module is not loaded' {
        InModuleScope Brownserve.PSBuildTools {
            Mock Get-Module { return $null }
            { Get-BrownserveLoadedModuleVersion -Name 'Brownserve.DoesNotExist' -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage '*not loaded*'
        }
    }

    It 'throws when more than one version of the module is loaded' {
        InModuleScope Brownserve.PSBuildTools {
            Mock Get-Module {
                return @(
                    [pscustomobject]@{ Version = [version]'1.0.0'; PrivateData = $null }
                    [pscustomobject]@{ Version = [version]'2.0.0'; PrivateData = $null }
                )
            }
            { Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSCommon' -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage '*Multiple versions*'
        }
    }

    It 'returns 0.0 when the loaded module is a working copy' {
        InModuleScope Brownserve.PSBuildTools {
            Mock Get-Module {
                return [pscustomobject]@{ Version = [version]'0.0'; PrivateData = $null }
            }
            Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSCommon' -ErrorAction 'Stop' | Should -Be '0.0'
        }
    }

    It 'appends the prerelease label when present' {
        InModuleScope Brownserve.PSBuildTools {
            Mock Get-Module {
                return [pscustomobject]@{
                    Version     = [version]'1.2.3'
                    PrivateData = @{ PSData = @{ Prerelease = 'beta1' } }
                }
            }
            Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSCommon' -ErrorAction 'Stop' | Should -Be '1.2.3-beta1'
        }
    }
}

Describe 'Compare-BrownserveRepository pin resolution' {
    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        Set-RepositorySnapshotMocks
    }

    It 'fails before producing any output when a Brownserve module is not loaded' {
        InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)
            Mock Get-BrownserveLoadedModuleVersion { throw "'Brownserve.PSCommon' is not loaded in this session." }
            { Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage '*not loaded*'
        }
    }

    It 'fails before producing any output when multiple versions of a Brownserve module are loaded' {
        InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)
            Mock Get-BrownserveLoadedModuleVersion { throw "Multiple versions of 'Brownserve.PSCommon' are loaded." }
            { Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage '*Multiple versions*'
        }
    }

    It 'pins the Brownserve module rules and preserves manually defined paket dependencies' {
        $ExistingPaketDependencies = @(
            '# This file is managed by a tool, manual changes will be lost unless added to the designated section below',
            'source https://api.nuget.org/v3/index.json',
            '',
            '## Auto generated dependencies: ##',
            'nuget Brownserve.PSCommon',
            '',
            '## Manually defined dependencies: ##',
            'nuget SomeManualPackage'
        ) -join "`n"
        Set-Content -Path (Join-Path $script:RepositoryPath 'paket.dependencies') -Value $ExistingPaketDependencies -NoNewline

        $Result = InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)
            Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -ErrorAction 'Stop'
        }

        $PaketFile = $Result.ChangedFiles | Where-Object { $_.Path -like '*paket.dependencies' }
        $PaketFile | Should -Not -BeNullOrEmpty
        $PaketContent = $PaketFile.Content -join "`n"
        $PaketContent | Should -Match ([regex]::Escape('nuget Brownserve.PSCommon = 1.2.3'))
        $PaketContent | Should -Match ([regex]::Escape('nuget Brownserve.PSSourceControl = 2.3.4'))
        $PaketContent | Should -Match ([regex]::Escape('nuget Brownserve.PSBuildTools = 3.4.5'))
        $PaketContent | Should -Match ([regex]::Escape('nuget SomeManualPackage'))
    }

    It 'throws for an unparsable .gitignore without -Force' {
        Set-Content -Path (Join-Path $script:RepositoryPath '.gitignore') -Value "bin/`nobj/" -NoNewline

        InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)
            { Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage "*can't be parsed*"
        }
    }

    It 'proposes the unparsable .gitignore as a changed file with -Force' {
        Set-Content -Path (Join-Path $script:RepositoryPath '.gitignore') -Value "bin/`nobj/" -NoNewline

        $Result = InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)
            Compare-BrownserveRepository -RepositoryPath $RepositoryPath -Components @() -RepoName 'test' -Force -ErrorAction 'Stop'
        }

        $GitIgnoreFile = $Result.ChangedFiles | Where-Object { $_.Path -like '*.gitignore' }
        $GitIgnoreFile | Should -Not -BeNullOrEmpty
    }
}

Describe 'Update-BrownserveRepository forwards -Force' {
    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        $script:BuildDirectory = Join-Path $script:RepositoryPath '.build'
        New-Item -Path $script:BuildDirectory -ItemType Directory -Force | Out-Null

        $Manifest = @{ RepositoryType = 'Generic'; ManifestVersion = '1.0.0' } | ConvertTo-Json
        Set-Content -Path (Join-Path $script:RepositoryPath '.brownserve_repository_manifest') -Value $Manifest
    }

    It 'passes -Force through to Compare-BrownserveRepository' {
        InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)

            Mock Assert-Command { }
            Mock Compare-BrownserveRepository {
                return [pscustomobject]@{
                    MissingFiles       = @()
                    ChangedFiles       = @()
                    MissingDirectories = @()
                }
            }

            Update-BrownserveRepository -RepositoryPath $RepositoryPath -Force -ErrorAction 'Stop'

            Should -Invoke Compare-BrownserveRepository -Times 1 -Exactly -ParameterFilter { $Force -eq $true }
        }
    }

    It 'does not force Compare-BrownserveRepository when -Force is not supplied' {
        InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $script:RepositoryPath } {
            param($RepositoryPath)

            Mock Assert-Command { }
            Mock Compare-BrownserveRepository {
                return [pscustomobject]@{
                    MissingFiles       = @()
                    ChangedFiles       = @()
                    MissingDirectories = @()
                }
            }

            Update-BrownserveRepository -RepositoryPath $RepositoryPath -ErrorAction 'Stop'

            Should -Invoke Compare-BrownserveRepository -Times 1 -Exactly -ParameterFilter { $Force -eq $false }
        }
    }
}
