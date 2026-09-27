@{
    Requires = @('ReleaseLifecycle')
    Options  = @(
        @{ Name = 'ModuleInfo'; Type = 'BrownservePowerShellModule'; Required = $true }
        @{ Name = 'UseWorkingCopy'; Type = 'bool'; Default = $false; Required = $false }
        @{ Name = 'DisableGitHubActionsCooldown'; Type = 'bool'; Default = $true; Required = $false }
        @{ Name = 'IncludeLicense'; Type = 'bool'; Default = $true; Required = $false }
    )
    Data     = @{
        PermanentPaths    = @(
            @{
                VariableName = 'BrownserveModuleDirectory'
                Path         = 'Module'
                Description  = 'Stores the PowerShell module'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoTestsDirectory'
                Path         = '.build'
                ChildPaths   = 'tests'
                Description  = 'Stores any tests that we pass to Pester'
                PathType     = 'Directory'
            }
        )
        PaketDependencies = @(
            @{
                Comment = 'Pester is used to perform testing on the PowerShell module'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'Pester' }
                )
            }
            @{
                Comment = 'To push the module up to nuget.org we use the standalone version of Nuget.'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'NuGet.CommandLine' }
                )
            }
        )
        VSCodeExtensions  = @(
            @{
                ExtensionID    = 'ms-vscode.powershell'
                CustomSettings = @{
                    'powershell.helpCompletion'                             = 'Disabled'
                    'powershell.codeFormatting.trimWhitespaceAroundPipe'    = $true
                    'powershell.codeFormatting.useConstantStrings'         = $true
                    'powershell.codeFormatting.autoCorrectAliases'         = $true
                    'powershell.codeFormatting.pipelineIndentationStyle'   = 'IncreaseIndentationAfterEveryPipeline'
                    'powershell.codeFormatting.preset'                     = 'Allman'
                    'powershell.codeFormatting.useCorrectCasing'           = $true
                }
            }
            @{
                ExtensionID    = 'streetsidesoftware.code-spell-checker'
                CustomSettings = @{
                    'cSpell.words' = @('Allman', 'Cmdlets', 'Dont', 'hashtable', 'hashtables', 'imatch', 'LASTEXITCODE', 'MAML', 'Mddhhmm', 'notcontains', 'notlike', 'notmatch', 'pscustomobject', 'PSGALLERY', 'PSMODULE', 'psobject', 'pstools', 'pwsh')
                }
            }
            @{
                ExtensionID    = 'yzhang.markdown-all-in-one'
                CustomSettings = @{
                    'markdown.extension.toc.omittedFromToc' = @{ 'README.md' = @('# Overview') }
                    'markdown.extension.toc.updateOnSave'   = $false
                }
            }
            @{
                ExtensionID    = 'EditorConfig.EditorConfig'
                CustomSettings = @{}
            }
            @{
                ExtensionID    = 'DavidAnson.vscode-markdownlint'
                CustomSettings = @{}
            }
        )
        PackageAliases    = @(
            @{ Alias = 'nuget'; FileName = 'NuGet.exe'; VariableName = 'BrownserveNugetPath' }
        )
        Devcontainer      = @{ Dockerfile = 'Dockerfile_PowerShellModule' }
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'nuget'; Directory = '/.config'; Interval = 'weekly' }
        )
        InitParams        = @{
            IncludePowerShellYaml = $true
            IncludePlatyPS        = $true
        }
    }
}
