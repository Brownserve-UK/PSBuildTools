@{
    Requires = @('ReleaseLifecycle')
    Options  = @(
        @{ Name = 'PackageId'; Type = 'string'; Required = $true }
        @{ Name = 'PackageDescription'; Type = 'string'; Required = $true }
        @{ Name = 'PackageAuthor'; Type = 'string'; Default = 'Brownserve UK'; Required = $false }
        @{ Name = 'PackageTags'; Type = 'array'; Default = @('brownserve-UK'); Required = $false }
        @{ Name = 'UseWorkingCopy'; Type = 'bool'; Default = $false; Required = $false }
    )
    Data     = @{
        PermanentPaths    = @(
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
                Comment = 'Pester is used to perform testing on the build scripts'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'Pester' }
                )
            }
            @{
                Comment = 'To pack and push the package up to nuget.org we use the standalone version of Nuget.'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'NuGet.CommandLine' }
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
        PackageAliases    = @(
            @{ Alias = 'nuget'; FileName = 'NuGet.exe'; VariableName = 'BrownserveNugetPath' }
        )
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'nuget'; Directory = '/.config'; Interval = 'weekly' }
        )
        BuildTasks        = @{
            TaskFile             = 'NuGetPackage.tasks.ps1'
            Parameters           = @('PackageId', 'PackageDescription', 'PackageAuthor', 'PackageTags', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubReleaseToken', 'NugetFeedApiKey', 'CustomNugetFeeds')
            OptionParameterMap   = @{ PackageId = 'PackageId'; PackageDescription = 'PackageDescription'; PackageAuthor = 'PackageAuthor'; PackageTags = 'PackageTags' }
            SkipParameters       = @()
            Types                = @{ NugetFeedApiKey = 'string'; CustomNugetFeeds = 'hashtable[]' }
            Descriptions         = @{
                NugetFeedApiKey  = 'The API key to use when publishing to a NuGet feed'
                CustomNugetFeeds = 'Any custom/private NuGet feeds to publish to'
            }
            PublicTargets        = @()
            PublicTargetAnchors  = @{}
            PublishValues        = @('nuget', 'GitHub', 'CustomNugetFeeds')
            Toolchains           = @(
                @{ Tools = @('mono'); Anchors = @('Package'); Platform = 'NonWindows' }
            )
            CollectorParameter   = $null
        }
    }
}
