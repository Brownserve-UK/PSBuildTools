<#
.SYNOPSIS
    Parses the generated section of a '.editorconfig' file into section/property pairs.
.DESCRIPTION
    Used by the structured 'Merged' file pipeline to compare the '.editorconfig' file on disk against our
    previous and current contributions on a per (section, property) basis. Comments, the 'root = true' line
    and blank lines are ignored. Returns an array of '[pscustomobject]' with 'Section' and an ordered
    'Properties' dictionary, in the order the sections were encountered, so the original layout can be
    reconstructed for anything we don't recognise as our own.
#>
function ConvertFrom-BrownserveEditorConfigText
{
    [CmdletBinding()]
    param
    (
        # The lines of the generated (pre-manual-marker) section of the file
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]
        $Content = @()
    )
    process
    {
        $Sections = [System.Collections.Generic.List[pscustomobject]]::new()
        $Current = $null
        foreach ($Line in $Content)
        {
            $Trimmed = $Line.Trim()
            if ($Trimmed -eq '' -or $Trimmed.StartsWith('#'))
            {
                continue
            }
            if ($Trimmed -match '^\[(.+)\]$')
            {
                $SectionName = $Matches[1]
                $Current = $Sections | Where-Object { $_.Section -eq $SectionName } | Select-Object -First 1
                if (!$Current)
                {
                    $Current = [pscustomobject]@{
                        Section    = $SectionName
                        Properties = [ordered]@{}
                    }
                    $Sections.Add($Current)
                }
                continue
            }
            if ($Trimmed -match '^([A-Za-z_]+)\s*=\s*(.+)$')
            {
                $PropertyName = $Matches[1].Trim()
                $PropertyValue = $Matches[2].Trim()
                if ($PropertyName -eq 'root')
                {
                    continue
                }
                if (!$Current)
                {
                    continue
                }
                $Current.Properties[$PropertyName] = $PropertyValue
            }
        }
        return $Sections.ToArray()
    }
}
