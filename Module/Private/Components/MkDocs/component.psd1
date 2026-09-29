@{
    Requires = @('ReleaseLifecycle', 'PowerShellModule')
    Options  = @()
    Data     = @{
        IncludeMkDocs = $true
        CI            = @{
            DeployDocs = @{ Engine = 'mkdocs'; Permissions = @('WriteContents') }
        }
    }
}
