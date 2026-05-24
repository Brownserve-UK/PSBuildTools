<#
.SYNOPSIS
    Updates the PlatyPS module page module description field.
.DESCRIPTION
    The Update-MarkdownHelpModule cmdlet in the PlatyPS module doesn't support updating the module description in the module
    page.
    This cmdlet will set the module description in the module page to the description specified.
.#>
function Update-PlatyPSModulePageDescription
{
    [CmdletBinding()]
    param
    (
        # The description of the module
        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleDescription,

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

        # We don't yet support automatically updating the module description in the module page.
        # only setting it if it's not already set.
        if ($ModulePageContentString -imatch '## Description[\s\n]*{{ Fill in the Description }}')
        {
            # .Replace method doesn't work 🤷‍♀️ so use the -replace param instead.
            $NewModulePageContent = $ModulePageContentString -Replace '## Description[\s\n]*{{ Fill in the Description }}', "## Description`n`n$ModuleDescription"
            $ModulePageContent.Content = $NewModulePageContent | Format-BrownserveContent | Select-Object -ExpandProperty Content

            return $ModulePageContent
        }
        else
        {
            Write-Verbose 'Module page description already set'
            return $ModulePageContent
        }
    }
    end
    {
    }
}
