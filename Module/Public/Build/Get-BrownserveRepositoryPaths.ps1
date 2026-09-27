<#
.SYNOPSIS
    Returns the permanent paths that should exist in a Brownserve repository based on its configured components.
.DESCRIPTION
    Reads the repository's '.brownserve_repository_manifest' (migrating a legacy v1 manifest in memory if
    necessary) and returns the permanent paths contributed by 'Core' plus every configured component.
    Ephemeral paths are not returned as they are not guaranteed to exist and are (re)created by the _init script.
.PARAMETER RepositoryPath
    The path to the repository.
.EXAMPLE
    Get-BrownserveRepositoryPaths -RepositoryPath .
#>
function Get-BrownserveRepositoryPaths
{
    [CmdletBinding()]
    param
    (
        # The path to the repository
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $RepositoryPath
    )
    process
    {
        $ManifestPath = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        if (!(Test-Path $ManifestPath))
        {
            throw "The repository at $RepositoryPath does not appear to have been configured. No manifest file found at $ManifestPath"
        }
        try
        {
            $Manifest = Get-Content -Path $ManifestPath -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        catch
        {
            throw "Failed to read repository manifest file.`n$($_.Exception.Message)"
        }

        $ModuleInfoPath = Join-Path $RepositoryPath '.build' 'ModuleInfo.json'
        $ExistingModuleInfo = $null
        if (Test-Path $ModuleInfoPath)
        {
            try
            {
                $ModuleInfoData = Get-Content $ModuleInfoPath -Raw -ErrorAction 'Stop' | ConvertFrom-Json -AsHashtable
                $ExistingModuleInfo = [BrownservePowerShellModule]$ModuleInfoData
            }
            catch
            {
                throw "Failed to load module info.`n$($_.Exception.Message)"
            }
        }

        if ($Manifest.ManifestVersion -like '2.*')
        {
            $Components = @($Manifest.Components | ForEach-Object { $_.Name })
            $ComponentOptions = @{}
            foreach ($ManifestComponent in $Manifest.Components)
            {
                if ($ManifestComponent.Options)
                {
                    $ComponentOptions[$ManifestComponent.Name] = @{} + $ManifestComponent.Options
                }
            }
        }
        else
        {
            if (!$Manifest.RepositoryType)
            {
                throw "The repository manifest file at $ManifestPath does not contain a RepositoryType property."
            }
            try
            {
                $Migrated = ConvertTo-BrownserveRepoComponentFromLegacyType `
                    -RepositoryType $Manifest.RepositoryType `
                    -ModuleInfo $ExistingModuleInfo `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to migrate legacy repository manifest.`n$($_.Exception.Message)"
            }
            $Components = $Migrated.Components
            $ComponentOptions = $Migrated.ComponentOptions
        }

        if ($Components -contains 'PowerShellModule' -and $ExistingModuleInfo)
        {
            if (!$ComponentOptions.ContainsKey('PowerShellModule'))
            {
                $ComponentOptions['PowerShellModule'] = @{}
            }
            $ComponentOptions['PowerShellModule']['ModuleInfo'] = $ExistingModuleInfo
        }

        try
        {
            $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
            $ResolvedComponents = Resolve-BrownserveRepoComponent -Name $Components -Options $ComponentOptions -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to resolve repository components.`n$($_.Exception.Message)"
        }

        $RepositoryPaths = @()
        foreach ($Component in $ResolvedComponents)
        {
            $Data = $Definitions[$Component.Name].Data
            if ($Data.PermanentPaths)
            {
                $RepositoryPaths += $Data.PermanentPaths
            }
            if ($Component.Name -eq 'DirectoryArchive' -and $Data.PermanentPathTemplate)
            {
                $SkillsPath = @{} + $Data.PermanentPathTemplate
                $SkillsPath.Path = $Component.Options.Path
                $RepositoryPaths += $SkillsPath
            }
        }

        $SeenPathVariables = @{}
        $UniquePaths = @()
        foreach ($PathEntry in $RepositoryPaths)
        {
            if (!$SeenPathVariables.ContainsKey($PathEntry.VariableName))
            {
                $SeenPathVariables[$PathEntry.VariableName] = $true
                $UniquePaths += $PathEntry
            }
        }

        if ($UniquePaths.Count -gt 0)
        {
            return $UniquePaths
        }
        else
        {
            return $null
        }
    }
}
