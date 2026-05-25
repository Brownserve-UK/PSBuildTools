function New-GitIgnoresFile
{
    [CmdletBinding()]
    param
    (
        # The list of items to be git-ignored
        [Parameter(Mandatory = $true)]
        [GitIgnore[]]
        $GitIgnores,

        # Any manual defined git-ignores
        [Parameter(Mandatory = $false, DontShow)]
        [String]
        $ManualGitIgnores
    )
    begin
    {
    }
    process
    {
        $IgnoresTemplate = "# This file is created by a tool, manual changes will be lost unless added to the designated section below.`n`n"
        if ($GitIgnores)
        {
            $IgnoresTemplate += "## Auto generated ignores: ##`n"
            $GitIgnores | ForEach-Object {
                if ($_.Comment)
                {
                    $IgnoresTemplate += "$($_.Comment)`n"
                }
                $_.Item | ForEach-Object {
                    $IgnoresTemplate += "$($_)`n"
                }
                $IgnoresTemplate += "`n"
            }
        }
        $IgnoresTemplate += @"
## Manually defined ignores: ##`n
"@
        if (($ManualGitIgnores) -and ($ManualGitIgnores -ne ''))
        {
            Write-Debug "Adding the following manual .gitignore items:`n$ManualGitIgnores"
            $IgnoresTemplate += $ManualGitIgnores
        }
    }
    end
    {
        <#
            Ensure that the content is formatted correctly ready for output
        #>
        $IgnoresTemplate = $IgnoresTemplate | Format-BrownserveContent
        Return $IgnoresTemplate
    }
}
