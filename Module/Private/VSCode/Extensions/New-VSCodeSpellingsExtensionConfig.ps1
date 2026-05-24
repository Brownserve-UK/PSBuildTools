function New-VSCodeSpellingsExtensionConfig
{
    [CmdletBinding()]
    param
    (
        # Any custom words that should be included alongside the defaults
        [Parameter(Mandatory = $false)]
        [string[]]
        $CustomWords,

        # The languages that should be supported
        [Parameter(Mandatory = $false)]
        [string[]]
        $Language = @('en', 'en-GB')
    )
    
    begin
    {
        
    }
    
    process
    {
        $LanguageString = $Language -join ','
        $MergeParams = @{
            ErrorAction = 'Stop'
        }
        if ($CustomWords.Count -gt 0)
        {
            $MergeParams.Add('CustomWords',$CustomWords)
        }
        try
        {
            $WordList = Merge-VSCodeSpellings @MergeParams
        }
        catch
        {
            throw "Failed to generate spellings.`n$($_.Exception.Message)"
        }

        $SettingsHash = @{
            'cSpell.language' = $LanguageString
            'cSpell.words'    = $WordList
        }
        $ExtensionID = 'streetsidesoftware.code-spell-checker'
        $Return = [BrownserveVSCodeExtension]@{
            ExtensionID = $ExtensionID
            Settings = $SettingsHash
        }
    }
    
    end
    {
        if ($Return)
        {
            return $Return
        }
    }
}