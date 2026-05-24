function Add-BrownserveChangelogEntry
{
    [CmdletBinding()]
    param
    (
        # The path to the changelog file
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]
        $ChangelogPath = (Join-Path $PWD 'CHANGELOG.md'),

        # The content to be inserted into the changelog
        [Parameter(
            Mandatory = $true,
            Position = 1,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $NewContent,

        # Special hidden parameter to allow the cmdlet to be called from the pipeline using input already collected from Read-BrownserveChangelog
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            DontShow = $true
        )]
        [BrownserveChangeLog]
        $ChangelogObject
    )
    begin
    {}
    process
    {
        if (!(Test-Path $ChangelogPath))
        {
            throw "$ChangelogPath does not appear to be a valid path to a changelog"
        }

        # If we haven't piped in an object then get our information
        if (!$ChangelogObject)
        {
            Write-Verbose 'Parsing changelog information'
            try
            {
                $ChangelogObject = Read-BrownserveChangelog -ChangelogPath $ChangelogPath
            }
            catch
            {
                throw "Failed to get current changelog information.`n$($_.Exception.Message)"
            }
        }
        $ChangelogContent = $ChangelogObject.Content
        $InsertLine = $ChangelogObject.NewEntryInsertLine
        $ChangelogPath = $ChangelogObject.ChangelogPath

        <#
            We split the content into two parts separating at the insert line.
            This allows us to insert our new content in the right place.
        #>
        try
        {
            Write-Verbose 'Splitting text to insert the new values'
            $Text1 = $ChangelogContent[0..$InsertLine]
            if ($ChangelogObject.HasPlaceholder)
            {
                $Text2 = @()
            }
            else
            {
                $Text2 = $ChangelogContent[$InsertLine..$ChangelogContent.Length]
            }
            # Split our text by newline to get a nice array to merge with the others
            $NewText = $NewContent -split "`n"
            $NewText = $Text1 + $NewContent + $Text2
        }
        catch
        {
            throw "Failed to rebuild changelog.`n$($_.Exception.Message)"
        }

        # Set the content of the changelog
        try
        {
            Set-Content $ChangelogPath -Value $NewText -ErrorAction 'Stop'
            <#
                PowerShell seems to insist on doing inconsistent things with line endings when running on different OSes.
                This results in constant line ending change diffs in git which no amount of gitattributes seems to fix.
                Therefore we'll just force the line endings to be LF.
                This helps to keep the git history clean and avoid breaking builds.
            #>
            Set-LineEndings -Path $ChangelogPath -LineEnding LF -ErrorAction 'Stop'
        }
        catch
        {
            Write-Error "Failed to set changelog text.$($_.Exception.Message)"
        }
    }
    end
    {}
}
