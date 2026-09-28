@{
    Requires = @()
    Options  = @()
    Data     = @{
        LicenseType         = 'MIT'
        IncludeChangelog    = $true
        IncludeMarkdownlint = $true
        IncludeLabelPR      = $true
        IncludeContributing = $true
        IncludePRTemplate   = $true
        IncludeWorkflows    = $true
        IncludeBuildScripts = $true
        IncludePesterTests  = $true
        IncludeDependabot   = $true
        MarkdownlintRules   = @(
            @{ Name = 'MD013'; Value = $false }
            @{ Name = 'MD024'; Value = @{ siblings_only = $true } }
        )
        EditorConfig        = @(
            @{
                Comment    = @('Now that PowerShell is cross-platform we''ll just set the line endings to LF')
                FilePath   = '{*.ps1,*.psm1,*.psd1,*.ps1.template}'
                Properties = @(
                    @{ Name = 'end_of_line'; Value = 'lf' }
                    @{ Name = 'charset'; Value = 'utf-8' }
                    @{ Name = 'indent_style'; Value = 'space' }
                    @{ Name = 'indent_size'; Value = 4 }
                )
            }
        )
        DependabotBaseUpdate       = @{ Ecosystem = 'github-actions'; Directory = '/'; Interval = 'weekly' }
        DependabotBaseCooldownDays = 30
        InitParams          = @{
            IncludeBuildTestTools = $true
        }
        BuildTasks          = @{
            TaskFile             = 'ReleaseLifecycle.tasks.ps1'
            Parameters           = @('ReleaseType', 'BranchName', 'DefaultBranch', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubStageReleaseToken', 'GitHubReleaseToken')
            OptionParameterMap   = @{}
            SkipParameters       = @()
            Types                = @{}
            Descriptions         = @{}
            PublicTargets        = @()
            PublicTargetAnchors  = @{}
            PublishValues        = @()
            Toolchains           = @()
            CollectorParameter   = $null
        }
    }
}
