@{
    Requires = @('ReleaseLifecycle')
    Options  = @()
    Data     = @{
        IncludeAstroDocs  = $true
        PermanentPaths    = @(
            @{
                VariableName = 'BrownserveRepoPagesDirectory'
                Path         = 'pages'
                Description  = 'Stores the Astro project that builds our documentation site'
                PathType     = 'Directory'
            }
        )
        CI                = @{
            ChangePatterns = @('pages/')
            DeployDocs     = @{ Engine = 'astro'; Path = 'pages'; Permissions = @('WriteContents') }
        }
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'npm'; Directory = '/pages'; Interval = 'weekly'; CooldownDays = 30 }
        )
        BuildTasks        = @{
            TaskFile             = 'AstroDocs.tasks.ps1'
            Parameters           = @('DocsDirectory')
            OptionParameterMap   = @{}
            SkipParameters       = @('DocsDirectory')
            Types                = @{}
            Descriptions         = @{}
            PublicTargets        = @()
            PublicTargetAnchors  = @{}
            PublishValues        = @()
            Toolchains           = @(
                @{ Tools = @('npm'); Anchors = @('Build') }
            )
            CollectorParameter   = $null
        }
    }
}
