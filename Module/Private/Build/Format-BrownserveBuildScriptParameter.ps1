<#
.SYNOPSIS
    Renders a single PowerShell 'param()' block entry for a generated build.ps1 or build_tasks.ps1.
.DESCRIPTION
    Used by 'New-BrownserveBuildScript' and 'New-BrownserveBuildTasksScript' so every generated parameter
    (whether fixed or contributed by a component's 'BuildTasks' data) is rendered consistently.
#>
function Format-BrownserveBuildScriptParameter
{
    [CmdletBinding()]
    param
    (
        # The name of the parameter
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        # The PowerShell type of the parameter, e.g. 'string', 'string[]', 'switch'
        [Parameter(Mandatory = $false)]
        [string]
        $Type = 'string',

        # Whether the parameter is mandatory
        [Parameter(Mandatory = $false)]
        [bool]
        $Mandatory = $false,

        # A literal default value expression, e.g. "'main'" or "$Global:BrownserveRepoName"
        [Parameter(Mandatory = $false)]
        [string]
        $DefaultExpression,

        # The values to validate the parameter against, if any
        [Parameter(Mandatory = $false)]
        [string[]]
        $ValidateSet,

        # A short description rendered as a '#' comment above the parameter
        [Parameter(Mandatory = $false)]
        [string]
        $Description
    )
    process
    {
        $Lines = [System.Collections.Generic.List[string]]::new()
        if ($Description)
        {
            $Lines.Add("    # $Description")
        }
        $Lines.Add('    [Parameter(')
        $Lines.Add("        Mandatory = `$$Mandatory")
        $Lines.Add('    )]')
        if ($ValidateSet -and $ValidateSet.Count -gt 0)
        {
            $QuotedValues = @($ValidateSet | ForEach-Object { "'$_'" }) -join ', '
            $Lines.Add("    [ValidateSet($QuotedValues)]")
        }
        if ($Type -ne 'switch')
        {
            $Lines.Add("    [$Type]")
        }
        else
        {
            $Lines.Add('    [switch]')
        }
        $Declaration = "    `$$Name"
        if ($DefaultExpression)
        {
            $Declaration += " = $DefaultExpression"
        }
        $Lines.Add($Declaration)
        return ($Lines -join "`n")
    }
}
