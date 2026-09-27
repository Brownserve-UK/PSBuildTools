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

                [string[]]
                $Components = @(),

                [hashtable]
                $ComponentOptions = @{},

                # A plain hashtable describing a 'PowerShellModule' component's module info. Built into the
                # 'BrownservePowerShellModule' type inside the module's own scope, since that type isn't
                # resolvable from outside it.
                [hashtable]
                $ModuleInfoData,

                [switch]
                $Force
            )

            InModuleScope Brownserve.PSBuildTools -Parameters @{
                RepositoryPath   = $RepositoryPath
                Components       = $Components
                ComponentOptions = $ComponentOptions
                ModuleInfoData   = $ModuleInfoData
                Force            = [bool]$Force
            } {
                param($RepositoryPath, $Components, $ComponentOptions, $ModuleInfoData, $Force)
                if ($ModuleInfoData)
                {
                    if (!$ComponentOptions.ContainsKey('PowerShellModule'))
                    {
                        $ComponentOptions['PowerShellModule'] = @{}
                    }
                    $ComponentOptions['PowerShellModule']['ModuleInfo'] = [BrownservePowerShellModule]$ModuleInfoData
                }
                Compare-BrownserveRepository `
                    -RepositoryPath $RepositoryPath `
                    -Components $Components `
                    -ComponentOptions $ComponentOptions `
                    -RepoName 'test' `
                    -Force:$Force `
                    -ErrorAction 'Stop'
            }
        }

        function script:Get-BrownserveManifestContentFromResult
        {
            param
            (
                [Parameter(Mandatory = $true)]
                $Result,

                [Parameter(Mandatory = $true)]
                [string]
                $ManifestPath
            )

            $Entry = ($Result.ChangedFiles + $Result.MissingFiles) | Where-Object { $_.Path -eq $ManifestPath } | Select-Object -First 1
            if (!$Entry)
            {
                return $null
            }
            return ($Entry.Content -join "`n") | ConvertFrom-Json -Depth 100 -AsHashtable
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

    It 'never touches ModuleInfo.json after it has been created (Seeded)' {
        $ModuleInfoData = @{ Name = 'Example'; Description = 'x'; GUID = (New-Guid).ToString(); Tags = @('x') }

        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $ModuleInfoData
        Publish-BrownserveCompareResult -Result $First

        $ModuleInfoPath = Join-Path (Join-Path $script:RepositoryPath '.build') 'ModuleInfo.json'
        Set-Content -Path $ModuleInfoPath -Value '{"manual":true}' -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $ModuleInfoData
        $Second.ChangedFiles.Path | Should -Not -Contain $ModuleInfoPath
        $Second.ConflictedFiles.Path | Should -Not -Contain $ModuleInfoPath

        Remove-Item -Path $ModuleInfoPath -Force
        $Third = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('PowerShellModule') -ModuleInfoData $ModuleInfoData
        $Third.MissingFiles.Path | Should -Contain $ModuleInfoPath
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

    It 'merges dotnet-tools.json: keeps a repository-added tool and updates our own paket entry' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ToolsPath = Join-Path (Join-Path $script:RepositoryPath '.config') 'dotnet-tools.json'
        $ExistingTools = Get-Content -Path $ToolsPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ExistingTools.tools['some-other-tool'] = @{ version = '1.0.0'; commands = @('some-other-tool') }
        ($ExistingTools | ConvertTo-Json -Depth 100) | Set-Content -Path $ToolsPath -NoNewline

        Mock Invoke-NativeCommand -ModuleName Brownserve.PSBuildTools {
            param($FilePath, $ArgumentList, $WorkingDirectory, $ExitCodes, $PassThru, $SuppressOutput)
            if ($ArgumentList -contains 'nugetconfig')
            {
                Set-Content -Path (Join-Path $WorkingDirectory 'nuget.config') -Value $script:FixtureNugetConfig -NoNewline
            }
            elseif ($ArgumentList -contains 'tool-manifest')
            {
                Set-Content -Path (Join-Path $WorkingDirectory 'dotnet-tools.json') -Value $script:FixtureToolManifestBase -NoNewline
            }
            elseif ($ArgumentList -contains 'install')
            {
                $Updated = $script:FixtureToolManifestWithPaket -replace '8\.0\.3', '9.0.0'
                Set-Content -Path (Join-Path $WorkingDirectory 'dotnet-tools.json') -Value $Updated -NoNewline
            }
        }

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Not -Contain $ToolsPath
        $ChangedEntry = $Second.ChangedFiles | Where-Object { $_.Path -eq $ToolsPath }
        $ChangedEntry | Should -Not -BeNullOrEmpty
        $MergedTools = ($ChangedEntry.Content -join "`n") | ConvertFrom-Json -Depth 100 -AsHashtable
        $MergedTools.tools.'some-other-tool' | Should -Not -BeNullOrEmpty
        $MergedTools.tools.paket.version | Should -Be '9.0.0'
    }

    It 'merges package.json: keeps a repository-added dependency and script alongside our own' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive', 'AstroDocs') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } }
        Publish-BrownserveCompareResult -Result $First

        $PackageJsonPath = Join-Path (Join-Path $script:RepositoryPath 'pages') 'package.json'
        $ExistingPackageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ExistingPackageJson.dependencies['left-pad'] = '^1.0.0'
        $ExistingPackageJson.scripts['lint'] = 'echo lint'
        ($ExistingPackageJson | ConvertTo-Json -Depth 100) | Set-Content -Path $PackageJsonPath -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive', 'AstroDocs') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } }
        $Second.ConflictedFiles.Path | Should -Not -Contain $PackageJsonPath

        $Entry = ($Second.ChangedFiles + $Second.MissingFiles) | Where-Object { $_.Path -eq $PackageJsonPath } | Select-Object -First 1
        $MergedContent = if ($Entry)
        {
            ($Entry.Content -join "`n") | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        else
        {
            Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        $MergedContent.dependencies.'left-pad' | Should -Be '^1.0.0'
        $MergedContent.scripts.lint | Should -Be 'echo lint'
        $MergedContent.dependencies.astro | Should -Not -BeNullOrEmpty
    }

    It 'merges .vscode/settings.json: a user setting survives, an edit to a generated setting conflicts, and -Force replaces it' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $SettingsPath = Join-Path (Join-Path $script:RepositoryPath '.vscode') 'settings.json'
        $ExistingSettings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ExistingSettings['editor.tabSize'] = 4
        $ExistingSettings['cSpell.language'] = 'en'
        ($ExistingSettings | ConvertTo-Json -Depth 100) | Set-Content -Path $SettingsPath -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Contain $SettingsPath
        $Second.ChangedFiles.Path | Should -Not -Contain $SettingsPath

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        $Forced.ConflictedFiles.Path | Should -Not -Contain $SettingsPath
        Publish-BrownserveCompareResult -Result $Forced
        $ForcedSettings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ForcedSettings.'editor.tabSize' | Should -Be 4
        $ForcedSettings.'cSpell.language' | Should -Not -Be 'en'
    }

    It 'merges .vscode/extensions.json: a user-added extension survives, removing a recommended one conflicts, and -Force re-adds it' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ExtensionsPath = Join-Path (Join-Path $script:RepositoryPath '.vscode') 'extensions.json'
        $ExistingExtensions = Get-Content -Path $ExtensionsPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $OurExtension = $ExistingExtensions.recommendations | Select-Object -First 1
        $ExistingExtensions.recommendations = @($ExistingExtensions.recommendations | Where-Object { $_ -ne $OurExtension }) + @('example.user-added-extension')
        ($ExistingExtensions | ConvertTo-Json -Depth 100) | Set-Content -Path $ExtensionsPath -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Contain $ExtensionsPath

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        $Forced.ConflictedFiles.Path | Should -Not -Contain $ExtensionsPath
        Publish-BrownserveCompareResult -Result $Forced
        $ForcedExtensions = Get-Content -Path $ExtensionsPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $ForcedExtensions.recommendations | Should -Contain $OurExtension
        $ForcedExtensions.recommendations | Should -Contain 'example.user-added-extension'
    }

    It 'merges .editorconfig: a user section survives, an edit to a generated property conflicts, and -Force replaces it' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $EditorConfigPath = Join-Path $script:RepositoryPath '.editorconfig'
        $Original = Get-Content -Path $EditorConfigPath
        $Modified = $Original -replace '^indent_style = space$', 'indent_style = tab'
        Set-Content -Path $EditorConfigPath -Value $Modified

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Contain $EditorConfigPath

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        $Forced.ConflictedFiles.Path | Should -Not -Contain $EditorConfigPath
    }

    It 'preserves a manual .gitignore, paket.dependencies and _init.ps1 entry without -Force, and conflicts on a generated-section edit' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $GitIgnorePath = Join-Path $script:RepositoryPath '.gitignore'
        Add-Content -Path $GitIgnorePath -Value 'ScoresOnTheDoors.manual.ignore'

        $PaketPath = Join-Path $script:RepositoryPath 'paket.dependencies'
        Add-Content -Path $PaketPath -Value 'nuget SomeManualPackage'

        $InitPath = Join-Path (Join-Path $script:RepositoryPath '.build') '_init.ps1'
        $InitContent = Get-Content -Path $InitPath
        $StartLine = ($InitContent | Select-String -Pattern '### Start user defined _init steps' -SimpleMatch).LineNumber
        $NewInitContent = $InitContent[0..($StartLine - 1)] + '$Global:ManualStep = $true' + $InitContent[$StartLine..($InitContent.Count - 1)]
        Set-Content -Path $InitPath -Value $NewInitContent

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Path | Should -Not -Contain $GitIgnorePath
        $Second.ConflictedFiles.Path | Should -Not -Contain $PaketPath
        $Second.ConflictedFiles.Path | Should -Not -Contain $InitPath

        $GitIgnoreLine = Get-Content -Path $GitIgnorePath
        $GitIgnoreLine = $GitIgnoreLine -replace '^# This file is created by a tool.*$', '# manually edited generated section'
        Set-Content -Path $GitIgnorePath -Value $GitIgnoreLine

        $Third = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Third.ConflictedFiles.Path | Should -Contain $GitIgnorePath

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        $Forced.ConflictedFiles.Path | Should -Not -Contain $GitIgnorePath
    }

    It 'fails before writing anything when a file the manifest records as Merged has a damaged structure, even with -Force' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ToolsPath = Join-Path (Join-Path $script:RepositoryPath '.config') 'dotnet-tools.json'
        Set-Content -Path $ToolsPath -Value 'not valid json {{{' -NoNewline

        { Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath } | Should -Throw
        { Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force } | Should -Throw
    }

    It 'refuses an unrecorded unparsable dotnet-tools.json without -Force, and replaces it with -Force' {
        $ToolsConfigDirectory = Join-Path $script:RepositoryPath '.config'
        New-Item -Path $ToolsConfigDirectory -ItemType Directory -Force | Out-Null
        $ToolsPath = Join-Path $ToolsConfigDirectory 'dotnet-tools.json'
        Set-Content -Path $ToolsPath -Value 'not valid json {{{' -NoNewline

        { Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath } | Should -Throw

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Force
        @(@($Forced.ChangedFiles.Path) + @($Forced.MissingFiles.Path)) | Should -Contain $ToolsPath
    }

    It 'establishes a baseline without conflicts for a structured file the manifest recorded before Baselines existed' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        Publish-BrownserveCompareResult -Result $First

        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
        $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $Manifest.Files.'.vscode/settings.json'.Remove('Baseline')
        ($Manifest | ConvertTo-Json -Depth 100) | Set-Content -Path $ManifestPath -NoNewline

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath
        $Second.ConflictedFiles.Count | Should -Be 0

        Publish-BrownserveCompareResult -Result $Second
        $SecondManifest = Get-BrownserveManifestContentFromResult -Result $Second -ManifestPath $ManifestPath
        $SecondManifest.Files.'.vscode/settings.json'.Baseline | Should -Not -BeNullOrEmpty
    }

    It 'removes unchanged Managed files owned by a dropped component, conflicts on a modified one, and -Force removes it while Merged/Seeded files are preserved' {
        $First = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive', 'AstroDocs') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } }
        Publish-BrownserveCompareResult -Result $First

        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
        $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -Depth 100 -AsHashtable
        $Manifest.Components = @($Manifest.Components | Where-Object { $_.Name -ne 'AstroDocs' })
        ($Manifest | ConvertTo-Json -Depth 100) | Set-Content -Path $ManifestPath -NoNewline

        $AstroConfigPath = Join-Path (Join-Path $script:RepositoryPath 'pages') 'astro.config.mjs'
        $PackageJsonPath = Join-Path (Join-Path $script:RepositoryPath 'pages') 'package.json'
        $IndexAstroPath = Join-Path (Join-Path (Join-Path (Join-Path $script:RepositoryPath 'pages') 'src') 'pages') 'index.astro'

        $Second = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } }

        # astro.config.mjs is Managed and unchanged since it was generated, so it's safe to remove outright
        ($Second.RemovedFiles | Where-Object { $_.Path -eq $AstroConfigPath }).Action | Should -Be 'Removed'
        $Second.ConflictedFiles.Path | Should -Not -Contain $AstroConfigPath

        ($Second.RemovedFiles | Where-Object { $_.Path -eq $PackageJsonPath }).Action | Should -Be 'Removed'
        Test-Path $PackageJsonPath | Should -Be $true

        # index.astro is Seeded, so it's left alone entirely and simply drops out of the manifest
        ($Second.RemovedFiles | Where-Object { $_.Path -eq $IndexAstroPath }).Action | Should -Be 'Skipped (Seeded)'
        Test-Path $IndexAstroPath | Should -Be $true
        $SecondManifest = Get-BrownserveManifestContentFromResult -Result $Second -ManifestPath $ManifestPath
        $SecondManifest.Files.ContainsKey('pages/src/pages/index.astro') | Should -Be $false
        $SecondManifest.Files.ContainsKey('pages/package.json') | Should -Be $false

        # Now modify astro.config.mjs by hand and confirm removing it becomes a conflict, resolved by -Force
        Add-Content -Path $AstroConfigPath -Value '// manual edit'

        $Third = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } }
        $Third.ConflictedFiles.Path | Should -Contain $AstroConfigPath
        ($Third.RemovedFiles | Where-Object { $_.Path -eq $AstroConfigPath }).Action | Should -Be 'Conflict'

        $Forced = Invoke-BrownserveCompare -RepositoryPath $script:RepositoryPath -Components @('DirectoryArchive') -ComponentOptions @{ DirectoryArchive = @{ Path = 'skills' } } -Force
        $Forced.ConflictedFiles.Count | Should -Be 0
        ($Forced.RemovedFiles | Where-Object { $_.Path -eq $AstroConfigPath }).Action | Should -Be 'Removed'
    }
}

Describe 'Set-BrownserveRepositoryState' {
    BeforeAll {
        Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
        Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
    }

    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
    }

    It 'writes every generated file before writing the manifest' {
        $FirstPath = Join-Path $script:RepositoryPath 'first.txt'
        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'

        $RepositoryState = [pscustomobject]@{
            MissingFiles       = @(
                [pscustomobject]@{ Path = $FirstPath; Content = @('one'); LineEnding = 'LF' }
                [pscustomobject]@{ Path = $ManifestPath; Content = @('manifest'); LineEnding = 'LF' }
            )
            ChangedFiles       = @()
            ConflictedFiles    = @()
            RemovedFiles       = @()
            MissingDirectories = @()
            ManifestPath       = $ManifestPath
        }

        InModuleScope Brownserve.PSBuildTools -Parameters @{
            RepositoryPath  = $script:RepositoryPath
            RepositoryState = $RepositoryState
        } {
            param($RepositoryPath, $RepositoryState)
            Set-BrownserveRepositoryState -RepositoryPath $RepositoryPath -RepositoryState $RepositoryState -ErrorAction 'Stop'
        }

        # '.brownserve_repository_manifest' is a dot-file (hidden on Unix), so 'Get-Item' needs '-Force' to see it
        (Get-Item -Path $FirstPath).LastWriteTimeUtc | Should -BeLessOrEqual (Get-Item -Path $ManifestPath -Force).LastWriteTimeUtc
    }

    It 'rolls back modified and created files, and leaves the manifest untouched, when a write fails partway through' {
        $ExistingFilePath = Join-Path $script:RepositoryPath 'existing.txt'
        Set-Content -Path $ExistingFilePath -Value 'original' -NoNewline
        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
        Set-Content -Path $ManifestPath -Value 'original manifest' -NoNewline
        $NewFilePath = Join-Path $script:RepositoryPath 'new.txt'
        # A file under a directory that's never created, so writing it fails naturally partway through the run
        $FailingFilePath = Join-Path (Join-Path $script:RepositoryPath 'does_not_exist') 'failing.txt'

        $RepositoryState = [pscustomobject]@{
            MissingFiles       = @(
                [pscustomobject]@{ Path = $NewFilePath; Content = @('created'); LineEnding = 'LF' }
            )
            ChangedFiles       = @(
                [pscustomobject]@{ Path = $ExistingFilePath; Content = @('changed'); LineEnding = 'LF' }
                [pscustomobject]@{ Path = $FailingFilePath; Content = @('never written'); LineEnding = 'LF' }
                [pscustomobject]@{ Path = $ManifestPath; Content = @('new manifest'); LineEnding = 'LF' }
            )
            ConflictedFiles    = @()
            RemovedFiles       = @()
            MissingDirectories = @()
            ManifestPath       = $ManifestPath
        }

        $ManifestBefore = Get-Content -Path $ManifestPath -Raw

        InModuleScope Brownserve.PSBuildTools -Parameters @{
            RepositoryPath  = $script:RepositoryPath
            RepositoryState = $RepositoryState
        } {
            param($RepositoryPath, $RepositoryState)
            { Set-BrownserveRepositoryState -RepositoryPath $RepositoryPath -RepositoryState $RepositoryState -ErrorAction 'Stop' } | Should -Throw
        }

        (Get-Content -Path $ExistingFilePath -Raw) | Should -Be 'original'
        Test-Path $NewFilePath | Should -Be $false
        Test-Path $FailingFilePath | Should -Be $false
        (Get-Content -Path $ManifestPath -Raw) | Should -Be $ManifestBefore
    }

    It 'rolls back everything, including the manifest, when the manifest write itself fails' {
        $ExistingFilePath = Join-Path $script:RepositoryPath 'existing.txt'
        Set-Content -Path $ExistingFilePath -Value 'original' -NoNewline
        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'
        Set-Content -Path $ManifestPath -Value 'original manifest' -NoNewline
        # Make the manifest itself unwritable so the very last step of the apply fails
        # ('-Force' is needed because a dot-file is hidden on Unix and 'Get-Item' skips hidden items by default)
        (Get-Item -Path $ManifestPath -Force).IsReadOnly = $true
        $NewFilePath = Join-Path $script:RepositoryPath 'new.txt'

        $RepositoryState = [pscustomobject]@{
            MissingFiles       = @(
                [pscustomobject]@{ Path = $NewFilePath; Content = @('created'); LineEnding = 'LF' }
            )
            ChangedFiles       = @(
                [pscustomobject]@{ Path = $ExistingFilePath; Content = @('changed'); LineEnding = 'LF' }
                [pscustomobject]@{ Path = $ManifestPath; Content = @('new manifest'); LineEnding = 'LF' }
            )
            ConflictedFiles    = @()
            RemovedFiles       = @()
            MissingDirectories = @()
            ManifestPath       = $ManifestPath
        }

        $ManifestBefore = Get-Content -Path $ManifestPath -Raw

        try
        {
            InModuleScope Brownserve.PSBuildTools -Parameters @{
                RepositoryPath  = $script:RepositoryPath
                RepositoryState = $RepositoryState
            } {
                param($RepositoryPath, $RepositoryState)
                { Set-BrownserveRepositoryState -RepositoryPath $RepositoryPath -RepositoryState $RepositoryState -ErrorAction 'Stop' } | Should -Throw
            }
        }
        finally
        {
            (Get-Item -Path $ManifestPath -Force).IsReadOnly = $false
        }

        (Get-Content -Path $ExistingFilePath -Raw) | Should -Be 'original'
        Test-Path $NewFilePath | Should -Be $false
        (Get-Content -Path $ManifestPath -Raw) | Should -Be $ManifestBefore
    }

    It 'removes files flagged for removal and still writes the manifest' {
        $ToRemovePath = Join-Path $script:RepositoryPath 'to_remove.txt'
        Set-Content -Path $ToRemovePath -Value 'goodbye' -NoNewline
        $ManifestPath = Join-Path $script:RepositoryPath '.brownserve_repository_manifest'

        $RepositoryState = [pscustomobject]@{
            MissingFiles       = @(
                [pscustomobject]@{ Path = $ManifestPath; Content = @('manifest'); LineEnding = 'LF' }
            )
            ChangedFiles       = @()
            ConflictedFiles    = @()
            RemovedFiles       = @(
                [pscustomobject]@{ Path = $ToRemovePath; Action = 'Removed' }
            )
            MissingDirectories = @()
            ManifestPath       = $ManifestPath
        }

        InModuleScope Brownserve.PSBuildTools -Parameters @{
            RepositoryPath  = $script:RepositoryPath
            RepositoryState = $RepositoryState
        } {
            param($RepositoryPath, $RepositoryState)
            Set-BrownserveRepositoryState -RepositoryPath $RepositoryPath -RepositoryState $RepositoryState -ErrorAction 'Stop'
        }

        Test-Path $ToRemovePath | Should -Be $false
        Test-Path $ManifestPath | Should -Be $true
    }

    It 'throws before touching anything when conflicts are present and -Force is not passed' {
        $ExistingFilePath = Join-Path $script:RepositoryPath 'existing.txt'
        Set-Content -Path $ExistingFilePath -Value 'original' -NoNewline

        $RepositoryState = [pscustomobject]@{
            MissingFiles       = @([pscustomobject]@{ Path = (Join-Path $script:RepositoryPath 'new.txt'); Content = @('x'); LineEnding = 'LF' })
            ChangedFiles       = @()
            ConflictedFiles    = @([pscustomobject]@{ Path = $ExistingFilePath; Reason = 'test conflict' })
            RemovedFiles       = @()
            MissingDirectories = @()
            ManifestPath       = (Join-Path $script:RepositoryPath '.brownserve_repository_manifest')
        }

        InModuleScope Brownserve.PSBuildTools -Parameters @{
            RepositoryPath  = $script:RepositoryPath
            RepositoryState = $RepositoryState
        } {
            param($RepositoryPath, $RepositoryState)
            { Set-BrownserveRepositoryState -RepositoryPath $RepositoryPath -RepositoryState $RepositoryState -ErrorAction 'Stop' } |
                Should -Throw '*modified since they were last generated*'
        }

        Test-Path (Join-Path $script:RepositoryPath 'new.txt') | Should -Be $false
    }
}
