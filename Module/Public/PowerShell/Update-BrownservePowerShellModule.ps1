function Update-BrownservePowerShellModule
{
    [CmdletBinding()]
    param
    (
        # The path where the PowerShell module should be created
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $Path,

        # Forces overwriting of files
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
    )
    begin
    {
    }
    process
    {
        if ($Path -notmatch '\.psm1$')
        {
            $Path = $Path + '.psm1'
        }
        Resolve-Path $Path -ErrorAction 'Stop' | Out-Null
        # Get the current module content
        $ModuleContent = Get-BrownserveContent -Path $Path -ErrorAction 'Stop'

        $ModuleParams = @{}
        try
        {
            $CustomisationSteps = $ModuleContent | Select-BrownserveContent `
                -After '### Start user defined module steps' `
                -Before '### End user defined module steps' `
                -FailIfNotFound `
                -ErrorAction 'Stop'
        }
        catch
        {
            if (!$Force)
            {
                throw "Failed to extract customisation steps from module.`n$($_.Exception.Message)"
            }
        }

        if ($CustomisationSteps)
        {
            $ModuleParams.Add('Customisations', $CustomisationSteps)
        }
        # Check to see if we've already got a required version of PowerShell
        if ($ModuleContent.ToString() -match '#Requires -Version ([0-9.]+)')
        {
            $ModuleParams.Add('RequirePowerShellVersion', $Matches[1])
        }
        # Check to see if BrownserveCmdlets logic is included
        if ($ModuleContent.ToString() -match 'BrownserveCmdlets')
        {
            $ModuleParams.Add('IncludeBrownserveCmdletsLogic', $true)
        }
        else
        {
            $ModuleParams.Add('IncludeBrownserveCmdletsLogic', $false)
        }
        # Check to see if we've already got a description - there's two potential formats we might find it in
        # believe me - you probably don't want to mess with this regex
        if ($ModuleContent.ToString() -match '(?m)\.DESCRIPTION\n([\s\S]+?)[\.^#]')
        {
            $ModuleParams.Add('Description', $Matches[1])
        }
        if ((!$ModuleParams.ContainsKey('Description')) -and ($ModuleContent.ToString() -match '(?m)\.DESCRIPTION\n([\s\S]+?)#'))
        {
            $ModuleParams.Add('Description', $Matches[1])
        }

        try
        {
            $ModuleTemplate = New-BrownservePoShModuleFromTemplate @ModuleParams -ErrorAction 'Stop'
            $NewModuleContent = $ModuleTemplate | Format-BrownserveContent -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to build module template.`n$($_.Exception.Message)"
        }

        $ModuleCompare = Compare-Object `
            -ReferenceObject $ModuleContent.Content `
            -DifferenceObject $NewModuleContent.Content `
            -SyncWindow 1 `
            -ErrorAction 'Stop'
        if ($ModuleCompare -or $Force)
        {
            try
            {
                $NewModuleContent | Set-BrownserveContent -Path $Path -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to create new module.`n$($_.Exception.Message)"
            }
        }
        else
        {
            Write-Verbose 'No changes required'
        }
    }
    end
    {
    }
}
