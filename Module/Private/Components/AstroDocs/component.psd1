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
        DependabotExtraUpdates = @(
            @{ Ecosystem = 'npm'; Directory = '/pages'; Interval = 'weekly'; CooldownDays = 30 }
        )
    }
}
