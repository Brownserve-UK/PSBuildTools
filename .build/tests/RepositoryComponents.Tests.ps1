#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

BeforeAll {
    . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
}

Describe 'Resolve-BrownserveRepoComponent' {
    It 'always includes Core even when nothing is requested' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = Resolve-BrownserveRepoComponent -Name @()
            $Result.Name | Should -Contain 'Core'
        }
    }

    It 'expands Requires transitively' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = Resolve-BrownserveRepoComponent -Name @('RustBinary')
            $Result.Name | Should -Contain 'ReleaseLifecycle'
            $Result.Name | Should -Contain 'RustBinary'
            $Result.Name | Should -Contain 'Core'
        }
    }

    It 'expands Requires for MkDocs (which needs PowerShellModule)' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Example'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = Resolve-BrownserveRepoComponent -Name @('MkDocs') -Options @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }
            $Result.Name | Should -Contain 'PowerShellModule'
            $Result.Name | Should -Contain 'ReleaseLifecycle'
        }
    }

    It 'returns components in a deterministic order regardless of request order' {
        InModuleScope Brownserve.PSBuildTools {
            $Options = @{ ContainerImage = @{}; }
            $A = (Resolve-BrownserveRepoComponent -Name @('RustBinary', 'ContainerImage')).Name
            $B = (Resolve-BrownserveRepoComponent -Name @('ContainerImage', 'RustBinary')).Name
            ($A -join ',') | Should -Be ($B -join ',')
        }
    }

    It 'throws for an unknown component' {
        InModuleScope Brownserve.PSBuildTools {
            { Resolve-BrownserveRepoComponent -Name @('DoesNotExist') -ErrorAction 'Stop' } | Should -Throw -ExpectedMessage "*Unknown component*"
        }
    }

    It 'throws for an unknown option' {
        InModuleScope Brownserve.PSBuildTools {
            { Resolve-BrownserveRepoComponent -Name @('RustBinary') -Options @{ RustBinary = @{ NotARealOption = $true } } -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage "*Unknown option*"
        }
    }

    It 'throws for an option with the wrong type' {
        InModuleScope Brownserve.PSBuildTools {
            { Resolve-BrownserveRepoComponent -Name @('ContainerImage') -Options @{ ContainerImage = @{ Context = 123 } } -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage "*expected type*"
        }
    }

    It 'throws when a required option is missing' {
        InModuleScope Brownserve.PSBuildTools {
            { Resolve-BrownserveRepoComponent -Name @('PowerShellModule') -ErrorAction 'Stop' } |
                Should -Throw -ExpectedMessage "*requires the option*"
        }
    }

    It 'applies defaults for options the caller did not supply' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Example'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = Resolve-BrownserveRepoComponent -Name @('PowerShellModule') -Options @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }
            $PowerShellModuleComponent = $Result | Where-Object { $_.Name -eq 'PowerShellModule' }
            $PowerShellModuleComponent.Options.UseWorkingCopy | Should -Be $false
        }
    }
}

Describe 'Get-BrownserveLegacyRepositoryComponentMapping / ConvertTo-BrownserveRepoComponentFromLegacyType' {
    It 'maps every legacy repository type' {
        InModuleScope Brownserve.PSBuildTools {
            $Mapping = Get-BrownserveLegacyRepositoryComponentMapping
            foreach ($Type in [enum]::GetValues([BrownserveRepoProjectType]))
            {
                $Mapping.ContainsKey($Type.ToString()) | Should -BeTrue -Because "the mapping should cover '$Type'"
            }
        }
    }

    It 'migrates PowerShellModule to PowerShellModule + MkDocs' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Example'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'PowerShellModule' -ModuleInfo $ModuleInfo
            $Result.Components | Should -Contain 'PowerShellModule'
            $Result.Components | Should -Contain 'MkDocs'
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Not -Be $true
        }
    }

    It 'migrates BrownservePSTools to PowerShellModule + MkDocs with UseWorkingCopy set' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Example'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'BrownservePSTools' -ModuleInfo $ModuleInfo
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Be $true
        }
    }

    It 'migrates WebApp to ContainerImage with Context .' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'WebApp'
            $Result.Components | Should -Be @('ContainerImage')
            $Result.ComponentOptions.ContainerImage.Context | Should -Be '.'
        }
    }

    It 'migrates RustApp to RustBinary' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'RustApp'
            $Result.Components | Should -Be @('RustBinary')
        }
    }

    It 'migrates bsdev to RustBinary + ContainerImage with Context image' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'bsdev'
            $Result.Components | Should -Contain 'RustBinary'
            $Result.Components | Should -Contain 'ContainerImage'
            $Result.ComponentOptions.ContainerImage.Context | Should -Be 'image'
            $Result.ComponentOptions.ContainerImage.IncludeEnvIgnore | Should -Be $false
        }
    }

    It 'migrates SkillsRepo to DirectoryArchive + AstroDocs with Path skills' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'SkillsRepo'
            $Result.Components | Should -Contain 'DirectoryArchive'
            $Result.Components | Should -Contain 'AstroDocs'
            $Result.ComponentOptions.DirectoryArchive.Path | Should -Be 'skills'
        }
    }

    It 'migrates Generic to no components' {
        InModuleScope Brownserve.PSBuildTools {
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'Generic'
            $Result.Components.Count | Should -Be 0
        }
    }

    It 'detects the working copy for a PowerShellModule repository identified as Brownserve.PSCommon' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Brownserve.PSCommon'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'PowerShellModule' -ModuleInfo $ModuleInfo
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Be $true
        }
    }

    It 'detects the working copy for a PowerShellModule repository identified as Brownserve.PSSourceControl' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Brownserve.PSSourceControl'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'PowerShellModule' -ModuleInfo $ModuleInfo
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Be $true
        }
    }

    It 'detects the working copy for a PowerShellModule repository identified as Brownserve.PSBuildTools' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Brownserve.PSBuildTools'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'PowerShellModule' -ModuleInfo $ModuleInfo
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Be $true
        }
    }

    It 'does not enable the working copy for an unrelated PowerShellModule repository' {
        InModuleScope Brownserve.PSBuildTools {
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Some.Other.Module'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Result = ConvertTo-BrownserveRepoComponentFromLegacyType -RepositoryType 'PowerShellModule' -ModuleInfo $ModuleInfo
            $Result.ComponentOptions.PowerShellModule.UseWorkingCopy | Should -Not -Be $true
        }
    }
}

Describe 'New-BrownserveRepositoryManifest' {
    It 'only records explicitly requested components, not Core' {
        InModuleScope Brownserve.PSBuildTools {
            $Definitions = Get-BrownserveRepoComponentDefinition
            $Manifest = New-BrownserveRepositoryManifest -Components @('RustBinary') -Definitions $Definitions -GeneratedByVersion '1.2.3'
            $Manifest.Components.Name | Should -Be @('RustBinary')
            $Manifest.ManifestVersion | Should -Be '2.0.0'
            $Manifest.GeneratedBy.'Brownserve.PSBuildTools' | Should -Be '1.2.3'
        }
    }

    It 'only records non-default options' {
        InModuleScope Brownserve.PSBuildTools {
            $Definitions = Get-BrownserveRepoComponentDefinition
            $Manifest = New-BrownserveRepositoryManifest `
                -Components @('ContainerImage') `
                -ComponentOptions @{ ContainerImage = @{ Context = 'image'; Registries = @('GHCR', 'DockerHub') } } `
                -Definitions $Definitions `
                -GeneratedByVersion '1.2.3'
            $Entry = $Manifest.Components | Where-Object { $_.Name -eq 'ContainerImage' }
            $Entry.Options.Keys | Should -Be @('Context')
            $Entry.Options.Context | Should -Be 'image'
        }
    }

    It 'never records ModuleInfo' {
        InModuleScope Brownserve.PSBuildTools {
            $Definitions = Get-BrownserveRepoComponentDefinition
            $ModuleInfo = [BrownservePowerShellModule]@{ Name = 'Example'; Description = 'x'; GUID = (New-Guid); Tags = @('x') }
            $Manifest = New-BrownserveRepositoryManifest `
                -Components @('PowerShellModule') `
                -ComponentOptions @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } } `
                -Definitions $Definitions `
                -GeneratedByVersion '1.2.3'
            $Entry = $Manifest.Components | Where-Object { $_.Name -eq 'PowerShellModule' }
            $Entry.Options.Keys | Should -Not -Contain 'ModuleInfo'
        }
    }
}

Describe 'Initialize-BrownserveRepository rejects unknown components before any writes' {
    BeforeEach {
        Set-RepositorySnapshotMocks
    }

    It 'throws before creating any files' {
        $RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $RepositoryPath -ItemType Directory -Force | Out-Null

        { Initialize-BrownserveRepository -RepositoryPath $RepositoryPath -Components @('NotAComponent') -ErrorAction 'Stop' } |
            Should -Throw -ExpectedMessage "*Unknown component*"

        (Get-ChildItem -Path $RepositoryPath -Recurse -Force).Count | Should -Be 0
    }
}
