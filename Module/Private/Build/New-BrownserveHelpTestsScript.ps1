function New-BrownserveHelpTestsScript
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName
    )

    begin
    {
        try
        {
            $ScriptTemplate = Get-Content (Join-Path $PSScriptRoot 'templates' 'help.tests.ps1.template') -Raw
        }
        catch
        {
            throw "Failed to import help tests template.`n$($_.Exception.Message)"
        }
    }

    process
    {
        $ScriptTemplate = $ScriptTemplate -replace '###MODULE_NAME###', $ModuleName
        return $ScriptTemplate
    }

    end
    {
    }
}
