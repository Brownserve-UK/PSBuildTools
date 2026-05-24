function New-PaketDependenciesFile
{
    [CmdletBinding()]
    param
    (
        # The dependencies to be created
        [Parameter(Mandatory = $true)]
        [PaketDependency[]]
        $PaketDependencies,

        # Any manually defined dependencies
        [Parameter(Mandatory = $false)]
        [string]
        $ManualDependencies
    )
    begin
    {
    }
    process
    {
        $PaketDependenciesTemplate = "# This file is managed by a tool, manual changes will be lost unless added to the designated section below`n"
        # Add the main nuget source
        $PaketDependenciesTemplate += "source https://api.nuget.org/v3/index.json`n`n"
        if ($PaketDependencies)
        {
            $PaketDependenciesTemplate += "## Auto generated dependencies: ##`n"
            $PaketDependencies | ForEach-Object {
                if ($_.Comment)
                {
                    $PaketDependenciesTemplate += "$($_.Comment)`n"
                }
                $_.Rule | ForEach-Object {
                    $PaketDependenciesTemplate += "$($_.Source) $($_.PackageName)`n"
                }
                $PaketDependenciesTemplate += "`n"
            }
        }
        $PaketDependenciesTemplate += "## Manually defined dependencies: ##`n"
        if ($ManualDependencies)
        {
            $PaketDependenciesTemplate += $ManualDependencies
        }
    }
    end
    {
        <#
            Ensure there are no errant carriage returns in the template.
            Split the template into an array of strings for easy comparison.
        #>
        $PaketDependenciesTemplate = $PaketDependenciesTemplate | Format-BrownserveContent
        return $PaketDependenciesTemplate
    }
}
