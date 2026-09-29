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
        GitHubTemplates   = @(
            @{ Path = '.github/CONTRIBUTING.md'; TemplateName = 'PowerShellModule_github_contributing.md.template'; SubstitutionKeys = @(); Ownership = 'Managed' }
            @{ Path = '.github/pull_request_template.md'; TemplateName = 'PowerShellModule_github_pull_request_template.md.template'; SubstitutionKeys = @('MODULE_NAME', 'REPO_NAME', 'OWNER'); Ownership = 'Managed' }
        )
        CI                = @{
            ChangePatterns = @('module/', 'pages/Cmdlet reference/')
            PublishSecrets = @{
                nuget     = @('NuGetApiKey')
                PSGallery = @('PSGalleryApiKey')
            }
        }
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'nuget'; Directory = '/.config'; Interval = 'weekly' }
        )
        InitParams        = @{
            IncludePowerShellYaml = $true
            IncludePlatyPS        = $true
        }
        BuildTasks        = @{
            TaskFile             = 'PowerShellModule.tasks.ps1'
            Parameters           = @('ModuleName', 'ModuleGUID', 'ModuleDescription', 'ModuleAuthor', 'ModuleTags', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubReleaseToken', 'NugetFeedApiKey', 'PSGalleryAPIKey', 'CustomNugetFeeds', 'UseWorkingCopy')
            OptionParameterMap   = @{}
            ModuleInfoMap        = @{ ModuleName = 'Name'; ModuleGUID = 'GUID'; ModuleDescription = 'Description'; ModuleTags = 'Tags' }
            SkipParameters       = @()
            Types                = @{ ModuleAuthor = 'string'; NugetFeedApiKey = 'string'; PSGalleryAPIKey = 'string'; CustomNugetFeeds = 'hashtable[]'; UseWorkingCopy = 'switch' }
            Defaults             = @{ ModuleAuthor = 'Brownserve UK' }
            Descriptions         = @{
                ModuleAuthor     = 'The author of the module'
                NugetFeedApiKey  = 'The API key to use when publishing to a NuGet feed'
                PSGalleryAPIKey  = 'The API key to use when publishing to the PSGallery'
                CustomNugetFeeds = 'Any custom/private NuGet feeds to publish to'
                UseWorkingCopy   = 'If set, loads the working copy of the module from the module directory instead of the stable version restored by _init.ps1'
            }
            PublicTargets        = @('BuildAndImport', 'BuildWithDocs')
            PublicTargetAnchors  = @{
                'BuildAndImport' = @('Build')
                'BuildWithDocs'  = @('Build')
            }
            PublishValues        = @('nuget', 'PSGallery', 'GitHub', 'CustomNugetFeeds')
            Toolchains           = @(
                @{ Tools = @('mono'); Anchors = @('Package'); Platform = 'NonWindows' }
            )
            CollectorParameter   = $null
        }
    }
}
