function Get-BrownserveLoadedModuleVersion
{
    [CmdletBinding()]
    param
    (
        # The name of the module to check
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    begin
    {
    }
    process
    {
        $ModulesFound = Get-Module -Name $Name
        if (!$ModulesFound)
        {
            throw "'$Name' is not loaded in this session. Please import the packaged '$Name' module and try again."
        }
        $LoadedModules = @($ModulesFound)
        if ($LoadedModules.Count -gt 1)
        {
            throw "Multiple versions of '$Name' are loaded in this session. Please import only the packaged '$Name' module and try again."
        }
        $LoadedModule = $LoadedModules[0]
        $Version = $LoadedModule.Version.ToString()
        $Prerelease = $LoadedModule.PrivateData.PSData.Prerelease
        if ($Prerelease)
        {
            $Version = "$Version-$Prerelease"
        }
    }
    end
    {
        return $Version
    }
}
