@{
    Requires = @('ReleaseLifecycle')
    Options  = @(
        @{ Name = 'Path'; Type = 'string'; Default = 'skills'; Required = $false }
        @{ Name = 'ArchiveName'; Type = 'string'; Default = 'skills'; Required = $false }
    )
    Data     = @{
        PermanentPaths   = @(
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
                Comment = 'Pester is used to validate the skills and test the build scripts'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'Pester' }
                )
            }
        )
        GitIgnores       = @(
            @{
                Comment = 'Node dependencies and Astro build output/cache for the documentation site.'
                Item    = @('node_modules/', 'pages/dist/', 'pages/.astro/')
            }
        )
        EditorConfig     = @(
            @{
                Comment    = @('Shell scripts use LF line endings')
                FilePath   = '*.sh'
                Properties = @(
                    @{ Name = 'end_of_line'; Value = 'lf' }
                    @{ Name = 'charset'; Value = 'utf-8' }
                    @{ Name = 'indent_style'; Value = 'space' }
                    @{ Name = 'indent_size'; Value = 4 }
                )
            }
        )
        VSCodeExtensions = @(
            @{
                ExtensionID    = 'ms-vscode.powershell'
                CustomSettings = @{
                    'powershell.helpCompletion'                          = 'Disabled'
                    'powershell.codeFormatting.trimWhitespaceAroundPipe' = $true
                    'powershell.codeFormatting.useConstantStrings'       = $true
                    'powershell.codeFormatting.autoCorrectAliases'       = $true
                    'powershell.codeFormatting.pipelineIndentationStyle' = 'IncreaseIndentationAfterEveryPipeline'
                    'powershell.codeFormatting.preset'                   = 'Allman'
                    'powershell.codeFormatting.useCorrectCasing'         = $true
                }
            }
            @{ ExtensionID = 'EditorConfig.EditorConfig'; CustomSettings = @{} }
            @{ ExtensionID = 'DavidAnson.vscode-markdownlint'; CustomSettings = @{} }
        )
        CI                = @{
            ChangePatterns = @('{Path}/')
        }
        PermanentPathTemplate = @{
            VariableName = 'BrownserveRepoSkillsDirectory'
            Description  = 'Stores the agent skills that get packaged into each release'
            PathType     = 'Directory'
        }
        BuildTasks        = @{
            TaskFile             = 'DirectoryArchive.tasks.ps1'
            Parameters           = @('Path', 'ArchiveName', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubReleaseToken')
            OptionParameterMap   = @{ Path = 'Path'; ArchiveName = 'ArchiveName' }
            SkipParameters       = @()
            Types                = @{}
            Descriptions         = @{}
            PublicTargets        = @()
            PublicTargetAnchors  = @{}
            PublishValues        = @('GitHub')
            Toolchains           = @()
            CollectorParameter = $null
        }
    }
}
