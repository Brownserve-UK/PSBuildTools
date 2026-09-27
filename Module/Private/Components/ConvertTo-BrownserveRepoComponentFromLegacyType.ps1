<#
.SYNOPSIS
    Migrates a legacy (v1) repository type into the set of components/options that reproduce its behaviour.
.DESCRIPTION
    Looks up the legacy type in 'Get-BrownserveLegacyRepositoryComponentMapping' and, for PowerShell module
    repositories, works out whether the generated build script should default to loading the working copy of
    the module ('UseWorkingCopy'). This is automatic for the legacy 'BrownservePSTools' type, and for any
    'PowerShellModule' repository whose 'ModuleInfo.json' identifies it as 'Brownserve.PSCommon',
    'Brownserve.PSSourceControl' or 'Brownserve.PSBuildTools' (identified by module name, never by directory
    name, so a renamed checkout is still identified correctly).
#>
function ConvertTo-BrownserveRepoComponentFromLegacyType
{
    [CmdletBinding()]
    param
    (
        # The legacy repository type read from the v1 manifest
        [Parameter(Mandatory = $true)]
        [BrownserveRepoProjectType]
        $RepositoryType,

        # The PowerShell module metadata for 'PowerShellModule'/'BrownservePSTools' repositories, read from '.build/ModuleInfo.json'
        [Parameter(Mandatory = $false)]
        [BrownservePowerShellModule]
        $ModuleInfo
    )
    begin
    {
        $Mapping = Get-BrownserveLegacyRepositoryComponentMapping
        $WorkingCopyModuleNames = @('Brownserve.PSCommon', 'Brownserve.PSSourceControl', 'Brownserve.PSBuildTools')
    }
    process
    {
        $TypeName = $RepositoryType.ToString()
        if (!$Mapping.ContainsKey($TypeName))
        {
            throw "No component mapping found for legacy repository type '$TypeName'."
        }
        $MappingEntry = $Mapping[$TypeName]
        $Components = @($MappingEntry.Components)
        $ComponentOptions = @{}
        if ($MappingEntry.Options)
        {
            foreach ($ComponentName in $MappingEntry.Options.Keys)
            {
                $ComponentOptions[$ComponentName] = @{} + $MappingEntry.Options[$ComponentName]
            }
        }

        $UseWorkingCopy = $false
        if ($RepositoryType -eq [BrownserveRepoProjectType]::BrownservePSTools)
        {
            $UseWorkingCopy = $true
        }
        elseif ($RepositoryType -eq [BrownserveRepoProjectType]::PowerShellModule -and $ModuleInfo -and $ModuleInfo.Name -in $WorkingCopyModuleNames)
        {
            $UseWorkingCopy = $true
        }

        if ($Components -contains 'PowerShellModule')
        {
            if (!$ComponentOptions.ContainsKey('PowerShellModule'))
            {
                $ComponentOptions['PowerShellModule'] = @{}
            }
            if ($UseWorkingCopy)
            {
                $ComponentOptions['PowerShellModule']['UseWorkingCopy'] = $true
            }
            if ($ModuleInfo)
            {
                $ComponentOptions['PowerShellModule']['ModuleInfo'] = $ModuleInfo
            }
        }
    }
    end
    {
        return [pscustomobject]@{
            Components       = $Components
            ComponentOptions = $ComponentOptions
        }
    }
}
