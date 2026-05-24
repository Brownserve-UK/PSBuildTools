function Get-BrownserveRepositoryPaths
{
    [CmdletBinding()]
    param
    (
        # The path to the repository
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $RepositoryPath,

        # The config file to use that stores our permanent/ephemeral path configuration
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $RepositoryPathsConfigFile = (Join-Path $Script:BrownservePSToolsConfigDirectory 'repository_paths_config.json')
    )
    begin
    {
        try
        {
            $RepositoryPathsConfig = Read-ConfigurationFromFile $RepositoryPathsConfigFile
        }
        catch
        {
            throw "Failed to read repository paths configuration file.`n$($_.Exception.Message)"
        }
    }
    process
    {
        $RepositoryPaths = @()
        $ManifestPath = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        if (!(Test-Path $ManifestPath))
        {
            throw "The repository at $RepositoryPath does not appear to have been configured. No manifest file found at $ManifestPath"
        }
        try
        {
            $Manifest = Get-Content -Path $ManifestPath -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
            $RepositoryType = $Manifest.RepositoryType
            if (!$RepositoryType)
            {
                throw "The repository manifest file at $ManifestPath does not contain a RepositoryType property."
            }
            Write-Debug "RepositoryType: $RepositoryType"
        }
        catch
        {
            throw "Failed to read repository manifest file.`n$($_.Exception.Message)"
        }

        <#
            We only return the permanent paths as the ephemeral paths are not guaranteed to exist and will be created
            by the _init script if needed.
            The 'Defaults' key contains the permanent paths that _all_ repositories should have.
        #>
        $RepositoryPaths += $RepositoryPathsConfig.Defaults.PermanentPaths

        if ($RepositoryPathsConfig.$RepositoryType)
        {
            if ($RepositoryPathsConfig.$RepositoryType.PermanentPaths)
            {
                $RepositoryPaths += $RepositoryPathsConfig.$RepositoryType.PermanentPaths
            }
        }

        if ($RepositoryPaths.count -gt 0)
        {
            return $RepositoryPaths
        }
        else
        {
            return $null
        }
    }
    end
    {
    }
}
