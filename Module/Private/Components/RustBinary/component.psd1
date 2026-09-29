@{
    Requires = @('ReleaseLifecycle')
    Options  = @(
        @{ Name = 'Targets'; Type = 'array'; Default = @('x86_64-unknown-linux-gnu', 'x86_64-pc-windows-msvc', 'aarch64-apple-darwin'); Required = $false }
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
                Comment = 'Pester is used to perform testing on the build scripts and binary smoke tests'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'Pester' }
                )
            }
        )
        GitIgnores        = @(
            @{
                Comment = 'Cargo build output. Note: Cargo.lock is intentionally NOT ignored for binary applications.'
                Item    = 'target/'
            }
            @{
                Comment = 'Rust backup files created by certain editors.'
                Item    = '**/*.rs.bk'
            }
        )
        VSCodeExtensions  = @(
            @{ ExtensionID = 'rust-lang.rust-analyzer'; CustomSettings = @{} }
            @{ ExtensionID = 'tamasfe.even-better-toml'; CustomSettings = @{} }
            @{
                ExtensionID    = 'ms-vscode.powershell'
                CustomSettings = @{
                    'powershell.helpCompletion'                           = 'Disabled'
                    'powershell.codeFormatting.trimWhitespaceAroundPipe'  = $true
                    'powershell.codeFormatting.useConstantStrings'        = $true
                    'powershell.codeFormatting.autoCorrectAliases'        = $true
                    'powershell.codeFormatting.pipelineIndentationStyle'  = 'IncreaseIndentationAfterEveryPipeline'
                    'powershell.codeFormatting.preset'                    = 'Allman'
                    'powershell.codeFormatting.useCorrectCasing'          = $true
                }
            }
            @{ ExtensionID = 'EditorConfig.EditorConfig'; CustomSettings = @{} }
            @{ ExtensionID = 'DavidAnson.vscode-markdownlint'; CustomSettings = @{} }
        )
        EditorConfig      = @(
            @{
                Comment    = @('Rust source files follow the rustfmt convention of 4-space indentation')
                FilePath   = '*.rs'
                Properties = @(
                    @{ Name = 'end_of_line'; Value = 'lf' }
                    @{ Name = 'charset'; Value = 'utf-8' }
                    @{ Name = 'indent_style'; Value = 'space' }
                    @{ Name = 'indent_size'; Value = 4 }
                )
            }
            @{
                Comment    = @('TOML files (Cargo.toml etc) use 2-space indentation')
                FilePath   = '*.toml'
                Properties = @(
                    @{ Name = 'end_of_line'; Value = 'lf' }
                    @{ Name = 'charset'; Value = 'utf-8' }
                    @{ Name = 'indent_style'; Value = 'space' }
                    @{ Name = 'indent_size'; Value = 2 }
                )
            }
        )
        Devcontainer      = @{ Dockerfile = 'Dockerfile_RustApp' }
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'cargo'; Directory = '/'; Interval = 'weekly'; CooldownDays = 30 }
        )
        IncludeInstallScripts = $true
        CI                = @{
            ChangePatterns = @('Cargo\.toml$', 'Cargo\.lock$', '.*\.rs$')
            TargetOption   = 'Targets'
            PackageTarget  = 'RustBinary.Package'
        }
        GitHubActions     = @{
            Runners = @{
                'x86_64-unknown-linux-gnu' = 'ubuntu-latest'
                'x86_64-pc-windows-msvc'   = 'windows-latest'
                'aarch64-apple-darwin'     = 'macos-latest'
            }
        }
        BuildTasks             = @{
            TaskFile             = 'RustBinary.tasks.ps1'
            Parameters           = @('BinaryName', 'Target', 'Targets', 'ArchiveSourceDirectory', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubReleaseToken')
            OptionParameterMap   = @{ Targets = 'Targets' }
            SkipParameters       = @('BinaryName')
            Types                = @{ Target = 'string'; ArchiveSourceDirectory = 'string' }
            Descriptions         = @{
                Target                 = 'The Rust target triple to build for, used by the RustBinary.Package target'
                ArchiveSourceDirectory = 'Directory of pre-built archives to publish instead of building with cargo'
            }
            PublicTargets        = @('RustBinary.Check', 'RustBinary.Package')
            PublicTargetAnchors  = @{
                'RustBinary.Check'   = @('Build', 'Test')
                'RustBinary.Package' = @('Build', 'Package')
            }
            PublishValues        = @('GitHub')
            Toolchains           = @(
                @{ Tools = @('cargo'); Anchors = @('Build', 'Test', 'Package', 'Stage') }
            )
            CollectorParameter   = 'ArchiveSourceDirectory'
        }
    }
}
