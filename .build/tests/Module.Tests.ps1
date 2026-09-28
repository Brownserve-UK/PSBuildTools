#requires -Modules Pester
BeforeAll {
    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
}

Describe 'ModuleImport' {
    Context 'When Brownserve.PSBuildTools is imported' {
        It 'should import without error' {
            {
                Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
                Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
            } | Should -Not -Throw
        }
    }

    Context 'Exported cmdlets' {
        BeforeAll {
            $script:PublicDir  = Join-Path $Global:BrownserveRepoRootDirectory 'Module\Public'
            $script:PrivateDir = Join-Path $Global:BrownserveRepoRootDirectory 'Module\Private'

            $script:ExpectedCmdlets = Get-ChildItem -Path $script:PublicDir -Filter '*.ps1' -Recurse |
                Select-Object -ExpandProperty BaseName | Sort-Object

            $script:ExportedCmdlets = Get-Command -Module 'Brownserve.PSBuildTools' |
                Select-Object -ExpandProperty Name | Sort-Object
        }

        It 'should export every public source file as a cmdlet' {
            $Missing = $script:ExpectedCmdlets | Where-Object { $script:ExportedCmdlets -notcontains $_ }
            $Missing | Should -BeNullOrEmpty -Because 'every .ps1 file in Module\Public should be exported as a cmdlet'
        }

        It 'should not export cmdlets that have no public source file' {
            $Unexpected = $script:ExportedCmdlets | Where-Object { $script:ExpectedCmdlets -notcontains $_ }
            $Unexpected | Should -BeNullOrEmpty -Because 'every exported cmdlet must have a corresponding .ps1 file in Module\Public'
        }

        It 'should not export any private cmdlets' {
            $PrivateNames = Get-ChildItem -Path $script:PrivateDir -Filter '*.ps1' -Recurse |
                Select-Object -ExpandProperty BaseName
            $Leaked = $PrivateNames | Where-Object { $script:ExportedCmdlets -contains $_ }
            $Leaked | Should -BeNullOrEmpty -Because 'private cmdlets must not appear in the module public surface'
        }
    }
}

Describe 'ModuleSource' {
    It 'should not contain files or folders whose names start with a dot' {
        $DotItems = Get-ChildItem -Path (Join-Path $Global:BrownserveRepoRootDirectory 'Module') -Recurse -Force |
            Where-Object { $_.Name -like '.*' } |
            ForEach-Object { [System.IO.Path]::GetRelativePath($Global:BrownserveRepoRootDirectory, $_.FullName) }
        $DotItems | Should -BeNullOrEmpty -Because 'nuget pack and PSGallery publishing drop dot-prefixed files and folders, so they would be missing from the published module'
    }
}
