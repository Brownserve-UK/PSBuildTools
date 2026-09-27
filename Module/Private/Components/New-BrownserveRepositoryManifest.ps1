<#
.SYNOPSIS
    Builds the v2 '.brownserve_repository_manifest' data structure for a set of requested components.
.DESCRIPTION
    Only the components the caller explicitly asked for are recorded (not 'Core', and not anything pulled in
    purely via another component's 'Requires'), and only options whose value differs from that option's
    default. A 'PowerShellModule' component's 'ModuleInfo' option is never recorded here, it lives in
    '.build/ModuleInfo.json' instead.
#>
function New-BrownserveRepositoryManifest
{
    [CmdletBinding()]
    param
    (
        # The components the caller explicitly requested (excludes 'Core' and anything pulled in via 'Requires')
        [Parameter(Mandatory = $false)]
        [string[]]
        $Components = @(),

        # The options the caller supplied, keyed by component name
        [Parameter(Mandatory = $false)]
        [hashtable]
        $ComponentOptions = @{},

        # Every known component definition, as returned by 'Get-BrownserveRepoComponentDefinition'
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Definitions,

        # The currently loaded version of Brownserve.PSBuildTools
        [Parameter(Mandatory = $true)]
        [string]
        $GeneratedByVersion
    )
    process
    {
        $ManifestComponents = @()
        foreach ($ComponentName in $Components)
        {
            if ($ComponentName -eq 'Core')
            {
                continue
            }
            if (!$Definitions.ContainsKey($ComponentName))
            {
                throw "Unknown component '$ComponentName'."
            }
            $Definition = $Definitions[$ComponentName]
            $Supplied = @{}
            if ($ComponentOptions.ContainsKey($ComponentName))
            {
                $Supplied = $ComponentOptions[$ComponentName]
            }

            $NonDefaultOptions = [ordered]@{}
            foreach ($OptionDefinition in $Definition.Options)
            {
                if ($OptionDefinition.Name -eq 'ModuleInfo')
                {
                    continue
                }
                if (!$Supplied.ContainsKey($OptionDefinition.Name))
                {
                    continue
                }
                $Value = $Supplied[$OptionDefinition.Name]
                $IsDefault = $false
                if ($null -eq $Value -and $null -eq $OptionDefinition.Default)
                {
                    $IsDefault = $true
                }
                elseif ($Value -is [array] -and $OptionDefinition.Default -is [array])
                {
                    $IsDefault = (@(Compare-Object -ReferenceObject $Value -DifferenceObject $OptionDefinition.Default).Count -eq 0)
                }
                elseif ($Value -eq $OptionDefinition.Default)
                {
                    $IsDefault = $true
                }
                if (!$IsDefault)
                {
                    $NonDefaultOptions[$OptionDefinition.Name] = $Value
                }
            }

            $Entry = [ordered]@{ Name = $ComponentName }
            if ($NonDefaultOptions.Count -gt 0)
            {
                $Entry['Options'] = $NonDefaultOptions
            }
            $ManifestComponents += $Entry
        }

        return [ordered]@{
            ManifestVersion = '2.0.0'
            GeneratedBy     = [ordered]@{ 'Brownserve.PSBuildTools' = $GeneratedByVersion }
            CICD            = 'GitHubActions'
            Components      = $ManifestComponents
        }
    }
}
