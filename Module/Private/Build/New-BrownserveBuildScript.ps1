function New-BrownserveBuildScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeUseWorkingCopyOption,

        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK'
    )
    begin
    {
    }
    process
    {
        try
        {
            $ScriptTemplate = Get-Content (Join-Path $PSScriptRoot 'templates' psmodule_build_script.ps1.template) -Raw
        }
        catch
        {
            throw "Failed to import build script template.`n$($_.Exception.Message)"
        }

        $ScriptTemplate = $ScriptTemplate -replace '###OWNER###', $Owner

        if ($IncludeUseWorkingCopyOption)
        {
            $UseWorkingCopyParam = @'
,

    # If set will load the working copy of the module at the start of the build
    [Parameter(
        Mandatory = $false
    )]
    [switch]
    $UseWorkingCopy
'@
            $UseWorkingCopyBuildParam = @'

        UseWorkingCopy    = ($PSBoundParameters['UseWorkingCopy'] -eq $true)
'@
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_PARAM###', $UseWorkingCopyParam
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_BUILDPARAM###', $UseWorkingCopyBuildParam
        }
        else
        {
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_PARAM###', ''
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_BUILDPARAM###', ''
        }
    }
    end
    {
        Return $ScriptTemplate
    }
}
