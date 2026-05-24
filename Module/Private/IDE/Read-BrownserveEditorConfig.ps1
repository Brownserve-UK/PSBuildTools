<#
.SYNOPSIS
    Parses an editorconfig file to extract any manual changes.
#>
function Read-BrownserveEditorConfig
{
    [CmdletBinding()]
    param
    (
        # The path to the editorconfig file
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]
        $Path
    )
    begin
    {
    }
    process
    {
        $ManualSections = @()
        $BeginParsing = $false
        $EditorConfigContent = Get-Content -Path $Path -ErrorAction 'Stop'
        $EditorConfigContent | ForEach-Object {
            <#
                First look for the heading "# MANUAL CHANGES BELOW THIS LINE WILL BE PRESERVED" the line after this
                will be the start of any user defined sections.
                We want to extract these sections and store them in a variable.
            #>
            if ($BeginParsing -eq $false)
            {
                if ($_ -match '^# MANUAL CHANGES BELOW THIS LINE WILL BE PRESERVED$')
                {
                    $BeginParsing = $true
                }
            }
            else
            {
                $ManualSections += $_
            }
        }
    }
    end
    {
        if ($ManualSections.Count -gt 0)
        {
            return $ManualSections
        }
        else
        {
            if ($BeginParsing -eq $false)
            {
                throw "Unable to find the manual changes section in the editorconfig file."
            }
            return $null
        }
    }
}
