function New-BrownserveBuildTasksScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeUseWorkingCopyOption
    )

    begin
    {
        try
        {
            $ScriptTemplate = Get-Content (Join-Path $PSScriptRoot 'templates' psmodule_build_tasks.ps1.template) -Raw
        }
        catch
        {
            throw "Failed to import script template.`n$($_.Exception.Message)"
        }
    }

    process
    {
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
            $UseWorkingCopyTask = @'
<#
.SYNOPSIS
    Loads the working copy of the module from the module directory
.DESCRIPTION
    By default we pull in the latest _stable_ copy of the build modules from NuGet via the _init.ps1 script to run this build,
    however if we make changes to any of the cmdlets used in this build we won't get the changes until a new release
    is pushed.
    This task allows us to unload the stable version and reload the working copy of this module from the local copy of the repo.
#>
task UseWorkingCopy {
    if ($UseWorkingCopy -eq $true)
    {
        Write-Build White "Loading working copy of module from $Global:BrownserveModuleDirectory"
        if ((Get-Module $ModuleName))
        {
            Write-Warning "The current version of $ModuleName has been unloaded and replaced with the working copy from $Global:BrownserveModuleDirectory. `nFunctionality may be unstable"
            Remove-Module $ModuleName -Force -ErrorAction 'Stop' -Verbose:$false
        }
        Import-Module (Join-Path $Global:BrownserveModuleDirectory "$ModuleName.psm1") -Force -ErrorAction 'Stop' -Verbose:$false
    }
}
'@
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_PARAM###', $UseWorkingCopyParam
            $ScriptTemplate = $ScriptTemplate -replace '\n###USE_WORKING_COPY_TASK###\r?\n', "`n$UseWorkingCopyTask`n"
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_DEP###', 'UseWorkingCopy, '
        }
        else
        {
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_PARAM###', ''
            $ScriptTemplate = $ScriptTemplate -replace '\n###USE_WORKING_COPY_TASK###\r?\n', ''
            $ScriptTemplate = $ScriptTemplate -replace '###USE_WORKING_COPY_DEP###', ''
        }

        return $ScriptTemplate
    }

    end
    {
    }
}
