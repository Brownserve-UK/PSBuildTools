<#
.SYNOPSIS
    Updates the links to cmdlet documentation in the PlatyPS module page.
.DESCRIPTION
    When PlatyPS creates a module page the links it creates assume that the cmdlet documentation is in the same directory
    as the module page.
    This cmdlet will update the links to point to the correct location.
    We may be able to remove the below once this issue is resolved: https://github.com/PowerShell/platyPS/issues/451
#>
function Update-PlatyPSModulePageLinks
{
    [CmdletBinding()]
    param
    (
        # The path to where the cmdlet documentation is stored
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $CmdletDocumentationPath,

        # The content of the module page
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [ValidateNotNullOrEmpty()]
        [psobject]
        $ModulePageContent
    )
    begin
    {
    }
    process
    {
        $ModulePageContentString = $ModulePageContent.ToString()
        <#
            As it stands we expect the module page path to be one level above the cmdlet documentation path.
            e.g:
                | ModulePage.md
                | CmdletDocumentation
                    | Cmdlet1.md
                    | Cmdlet2.md
                    | Cmdlet3.md
            We may want to change this assumption in the future.
        #>
        $ModulePageAdjustment = Split-Path $CmdletDocumentationPath -Leaf
        $NewModulePageContent = $ModulePageContentString -replace '\(([\w|\d]*-[\w|\d]*.md)\)', "(./$ModulePageAdjustment/`$1)"

        $ModulePageContent.Content = $NewModulePageContent | Format-BrownserveContent | Select-Object -ExpandProperty Content

        return $ModulePageContent
    }
    end
    {
    }
}
