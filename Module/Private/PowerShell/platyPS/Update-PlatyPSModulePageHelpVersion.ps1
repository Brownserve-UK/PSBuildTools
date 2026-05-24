<#
.SYNOPSIS
    Updates the help version in the PlatyPS module page.
.DESCRIPTION
    The Update-MarkdownHelpModule cmdlet in the PlatyPS module doesn't support updating the help version in the module
    page.
    This cmdlet will check the module manifest for the version number header and update the help version to the version
    specified.
    This allows us to keep our help version and module version in sync.
#>
function Update-PlatyPSModulePageHelpVersion
{
    [CmdletBinding()]
    param
    (
        # The help version number to use
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [System.Management.Automation.SemanticVersion]
        $HelpVersion,

        # The path to the module page
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
        $NewHelpVersion = $HelpVersion.ToString()
        if ($ModulePageContentString -imatch 'Help Version: (?<version>.*)\n')
        {
            $CurrentHelpVersion = $Matches['version']
            if ($NewHelpVersion -ne $CurrentHelpVersion)
            {
                Write-Verbose 'Updating help version'
                $NewModulePageContent = $ModulePageContentString.Replace("Help Version: $CurrentHelpVersion", "Help Version: $NewHelpVersion")
            }
        }
        else
        {
            throw 'Failed to find help version in module page'
        }

        $ModulePageContent.Content = $NewModulePageContent | Format-BrownserveContent | Select-Object -ExpandProperty Content

        return $ModulePageContent
    }
    end
    {
    }
}
