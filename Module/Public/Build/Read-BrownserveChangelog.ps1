<#
.SYNOPSIS
    Reads in a changelog file and returns the contents as a custom object.
.DESCRIPTION
    This cmdlet will read in a changelog file and return the contents as a custom object.
    The changelog file must be in the standard Brownserve format.
#>
function Read-BrownserveChangelog
{
    [CmdletBinding()]
    param
    (
        # The path to the changelog file
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]
        $ChangelogPath,

        # The regex to use for version matching.
        # It should always contain a capture group named "version" as this is what the regex matcher will use to extract the version number
        [Parameter(
            Mandatory = $false,
            DontShow
        )]
        [string]
        $VersionPattern = '^#*\s\[v(?<version>(([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?)\]\((?:.*)\)\s\([0-9]+\-[0-9]+\-[0-9]+\)',

        # The regex pattern for matching the release URL.
        # It should always contain a capture group named "url" and this what the regex searched will use to extract your url
        [Parameter(
            Mandatory = $false,
            DontShow
        )]
        [string]
        $ReleaseURLPattern = '(?<url>[-a-zA-Z0-9@:%_\+.~#?&//=]{2,256}\.[a-z]{2,4}\b(?:\/[-a-zA-Z0-9@:%_\+.~#?&//=]*)?)',

        # The regex pattern for matching the date of the last release.
        # It should always contain a capture group named "date" and this what the regex searched will use to extract your date
        [Parameter(
            Mandatory = $false,
            DontShow
        )]
        [string]
        $ReleaseDatePattern = '\((?<date>[\d|-]*)\)'
    )
    begin
    {
        $Return = @()
    }
    process
    {
        # Import the changelog, we don't use the -Raw switch as we want to read the file line by line
        try
        {
            $Changelog = Get-Content $ChangelogPath
        }
        catch
        {
            throw "Failed to get changelog content.$($_.Exception.Message)"
        }

        # We'll read through the changelog line-by-line and keep a track of various important lines
        $LineCount = 0

        <#
            As we go through each line we'll begin building a version history
        #>
        $VersionHistory = @()

        <#
            Set up a bunch of variables that'll be used (and explained) later on
        #>
        $PreviousVersion = $null
        $PreviousReleaseDate = $null
        $PreviousURL = $null
        $ReleaseNotesStartOn = $null
        $ReleaseNotesEndOn = $null

        # Go through each line of the changelog
        $Changelog | ForEach-Object {
            $Line = $_.Trim()
            # See if the line matches a version
            $VersionMatch = [regex]::Match($Line, $VersionPattern)
            if ($VersionMatch.Success)
            {
                # Congratulations this line matches a version number. 🎉 we'll store it for use later
                $ThisVersion = [semver]$VersionMatch.Groups['version'].Value
                # This line should also contain a date of the release, we'll want that too
                $ReleaseDateMatch = [regex]::Match($Line, $ReleaseDatePattern)
                if ($ReleaseDateMatch.Success)
                {
                    $ThisReleaseDate = $ReleaseDateMatch.Groups['date'].Value
                }
                # Similarly this line should also contain a URL that points to the release, we'll want that too
                $ReleaseURLMatch = [regex]::Match($Line, $ReleaseURLPattern)
                if ($ReleaseURLMatch.Success)
                {
                    $ThisURL = $ReleaseURLMatch.Groups['url'].Value
                }
                if (-not $NewChangelogLine)
                {
                    <#
                        We need to know where to insert a new changelog entry.
                        As our changelog goes in descending order (newest releases at the top) the line to insert a new
                        entry is the line directly before the first version string we match against.
                    #>
                    $NewChangelogLine = $LineCount - 1
                }
                <#
                    If this is the first version we've matched against then we $PreviousVersion will be null.
                    We'll set PreviousVersion to version number we've just matched against.
                    The release notes for this version will start on the _next_ line after the version number so we'll
                    set ReleaseNotesStartOn to the current line number + 1
                    We'll also store the release date and URL for this version for use later
                #>
                if (-not $PreviousVersion)
                {
                    $PreviousVersion = $ThisVersion
                    $PreviousReleaseDate = $ThisReleaseDate
                    $PreviousURL = $ThisURL
                    $ReleaseNotesStartOn = $LineCount + 1
                }
                else
                {
                    <#
                        If we've reached this point then we've matched against another version number.
                        This means we've reached the end of the release notes for the previous version.
                        So we know that all the text between here and the previous version number is the release notes for
                        the previous version.
                        We'll create an object of the data we've gathered and add it to the version history.
                    #>
                    # The release notes will end on the line _before_ the previous version number
                    $ReleaseNotesEndOn = $LineCount - 1
                    $ThisReleaseNotes = $Changelog[$ReleaseNotesStartOn..$ReleaseNotesEndOn]

                    # Try to trim off any empty lines at the start and end of the release note text
                    $LastLine = $ThisReleaseNotes.Count
                    while (!$ThisReleaseNotes[-1])
                    {
                        $LastLine = $LastLine - 1
                        $ThisReleaseNotes = $ThisReleaseNotes[0..$LastLine]
                    }
                    $FirstLine = 0
                    while (!$ThisReleaseNotes[0])
                    {
                        $LastLine = $ThisReleaseNotes.Count
                        $FirstLine ++
                        $ThisReleaseNotes = $ThisReleaseNotes[$FirstLine..$LastLine]
                    }

                    $VersionHistory += [BrownserveVersionHistory]@{
                        Version      = $PreviousVersion
                        ReleaseDate  = $PreviousReleaseDate
                        URL          = $PreviousURL
                        ReleaseNotes = $ThisReleaseNotes
                    }


                    <#
                        Now we've added the previous version to the version history we can set the variables for the
                        current version and continue on our merry way.
                    #>
                    $PreviousVersion = $ThisVersion
                    $PreviousReleaseDate = $ThisReleaseDate
                    $PreviousURL = $ThisURL
                    $ReleaseNotesStartOn = $LineCount + 1
                }
            }
            # Finally increase the line count for the next loop
            $LineCount++
        }
        <#
            Once we've gone through the entire changelog we'll have a bunch of data for the last version.
            We know the release notes for the last version will end on the last line of the changelog.
        #>
        $LastReleaseNotes = $Changelog[$ReleaseNotesStartOn..$Changelog.Count]
        # Try to trim off any empty lines at the start and end of the release note text
        $LastLine = $LastReleaseNotes.Count
        while (!$LastReleaseNotes[-1])
        {
            $LastLine = $LastLine - 1
            $LastReleaseNotes = $LastReleaseNotes[0..$LastLine]
        }
        $FirstLine = 0
        while (!$LastReleaseNotes[0])
        {
            $LastLine = $LastReleaseNotes.Count
            $FirstLine ++
            $LastReleaseNotes = $LastReleaseNotes[$FirstLine..$LastLine]
        }
        $VersionHistory += [BrownserveVersionHistory]@{
            Version      = $PreviousVersion
            ReleaseDate  = $PreviousReleaseDate
            URL          = $PreviousURL
            ReleaseNotes = $LastReleaseNotes
        }
        $HasPlaceholder = $VersionHistory.Count -eq 1 -and $VersionHistory[0].Version -eq [semver]'0.0.0'
        $Return += [BrownserveChangelog]@{
            VersionHistory     = $VersionHistory
            NewEntryInsertLine = $NewChangelogLine # This will be the line that we can start inserting new entries into
            ChangelogPath      = $ChangelogPath
            Content            = $Changelog
            HasPlaceholder     = $HasPlaceholder
        }
    }
    end
    {
        if ($Return.Count -gt 0)
        {
            return $Return
        }
        else
        {
            return $null
        }
    }
}
