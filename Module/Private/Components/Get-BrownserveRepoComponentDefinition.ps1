<#
.SYNOPSIS
    Loads every repository component definition ('component.psd1') found under the components directory.
.DESCRIPTION
    Components are data-only 'component.psd1' files (read with 'Import-PowerShellDataFile' so nothing in them
    ever executes) that describe a piece of repository functionality (e.g. 'PowerShellModule', 'RustBinary').
    This cmdlet loads all of them and returns a hashtable keyed by component name so that both the resolver and
    'Compare-BrownserveRepository' can look up a component's 'Requires', 'Options' and 'Data'.
#>
function Get-BrownserveRepoComponentDefinition
{
    [CmdletBinding()]
    param
    (
        # The directory that contains one sub-directory per component, each holding a 'component.psd1' file
        [Parameter(Mandatory = $false)]
        [string]
        $ComponentsDirectory = $Script:BrownserveRepoComponentsDirectory
    )
    begin
    {
        if (!(Test-Path $ComponentsDirectory))
        {
            throw "Components directory not found at '$ComponentsDirectory'."
        }
    }
    process
    {
        $Definitions = @{}
        Get-ChildItem -Path $ComponentsDirectory -Directory -ErrorAction 'Stop' | ForEach-Object {
            $DefinitionPath = Join-Path $_.FullName 'component.psd1'
            if (Test-Path $DefinitionPath)
            {
                try
                {
                    $Raw = Import-PowerShellDataFile -Path $DefinitionPath -ErrorAction 'Stop'
                }
                catch
                {
                    throw "Failed to read component definition '$DefinitionPath'.`n$($_.Exception.Message)"
                }
                $Definitions[$_.Name] = [BrownserveRepoComponentDefinition]::new($_.Name, $Raw)
            }
        }
    }
    end
    {
        return $Definitions
    }
}
