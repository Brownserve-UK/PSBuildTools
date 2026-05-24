function Merge-VSCodeSpellings
{
    [CmdletBinding()]
    param
    (
        # The spellings file template
        [Parameter(Mandatory = $false)]
        [string]
        $SpellingsFile = (Join-Path $PSScriptRoot 'cSpell_settings.json'),

        # The users custom words
        [Parameter(Mandatory = $false)]
        [string[]]
        $CustomWords
    )
    
    begin
    {
        
    }
    
    process
    {
        try
        {
            $DefaultSpellings = Get-Content $SpellingsFile -Raw | 
                ConvertFrom-Json | 
                    Select-Object -ExpandProperty 'cSpell.words'

        }
        catch
        {
            throw "Failed to import default spellings list.`n$($_.Exception.Message)"
        }

        try
        {
            [string[]]$NewList = $DefaultSpellings
            # Go through our default spellings, if they are not in the list of words we've been given by the user then add them.
            if ($CustomWords)
            {
                $CustomWords | ForEach-Object {
                    if ($_ -notin $NewList)
                    {
                        $NewList += $_
                    }
                }
            }
            $NewList = $NewList | Sort-Object
        }
        catch
        {
            throw "Failed to merge custom spellings with defaults.`n$($_.Exception.Message)"
        }
    }
    
    end
    {
        if ($NewList)
        {
            return $NewList
        }
    }
}