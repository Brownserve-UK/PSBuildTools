@{
    Requires = @('ReleaseLifecycle')
    Options  = @(
        @{ Name = 'Context'; Type = 'string'; Default = '.'; Required = $false }
        @{ Name = 'Registries'; Type = 'array'; Default = @('GHCR', 'DockerHub'); Required = $false }
        @{ Name = 'IncludeEnvIgnore'; Type = 'bool'; Default = $true; Required = $false }
        @{ Name = 'IncludeShellEditorConfig'; Type = 'bool'; Default = $false; Required = $false }
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
        )
        EnvGitIgnore      = @{
            Comment = 'Environment files often contain secrets and should never be committed.'
            Item    = @('.env', '.env.*')
        }
        GitIgnores        = @(
            @{
                Comment = 'Docker build output and cache.'
                Item    = '.docker/'
            }
        )
        VSCodeExtensions  = @(
            @{ ExtensionID = 'ms-azuretools.vscode-docker'; CustomSettings = @{} }
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
        ShellEditorConfig = @{
            Comment    = @('Dockerfiles and shell scripts use LF line endings')
            FilePath   = '{Dockerfile,*.Dockerfile,Dockerfile_*,*.sh}'
            Properties = @(
                @{ Name = 'end_of_line'; Value = 'lf' }
                @{ Name = 'charset'; Value = 'utf-8' }
                @{ Name = 'indent_style'; Value = 'space' }
                @{ Name = 'indent_size'; Value = 4 }
            )
        }
        Devcontainer      = @{ Dockerfile = 'Dockerfile_WebApp' }
        CI                = @{
            ChangePatterns       = @('{Context}/')
            OptionChangePatterns = @(
                @{ Option = 'Context'; Value = '.'; Patterns = @('src/', 'Dockerfile', 'package\.json$') }
            )
            PublishSecrets       = @{ DockerHub = @('DockerHubUsername', 'DockerHubToken') }
            PublishPermissions   = @{ GHCR = @('WritePackages') }
        }
        BuildTasks        = @{
            TaskFile             = 'ContainerImage.tasks.ps1'
            Parameters           = @('ImageName', 'DockerContextPath', 'PublishTo', 'GitHubRepoOwner', 'DockerHubUsername', 'DockerHubToken', 'GHCRToken')
            OptionParameterMap   = @{ Context = 'DockerContextPath' }
            SkipParameters       = @('ImageName')
            Types                = @{ DockerHubUsername = 'string'; DockerHubToken = 'string'; GHCRToken = 'string' }
            Descriptions         = @{
                DockerHubUsername = 'DockerHub username, required when publishing to DockerHub'
                DockerHubToken    = 'DockerHub access token, required when publishing to DockerHub'
                GHCRToken         = 'Token for GitHub Container Registry, needs packages:write'
            }
            PublicTargets        = @('ContainerImage.Check')
            PublicTargetAnchors  = @{
                'ContainerImage.Check' = @('Build', 'Test')
            }
            PublishValues        = @('DockerHub', 'GHCR')
            PublishValuesOption  = 'Registries'
            Toolchains           = @(
                @{ Tools = @('docker'); Anchors = @('Build') }
            )
            CollectorParameter   = $null
        }
    }
}
