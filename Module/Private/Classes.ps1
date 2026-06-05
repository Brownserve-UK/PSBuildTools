<#
.DESCRIPTION
    Private classes for Brownserve.PSBuildTools.
    All classes are consolidated here to guarantee load order and avoid 'type not found' errors
    when classes depend on other classes defined in this module.
#>

## Changelog and versioning classes

<#
    Simple class to ensure datetime objects are displayed as short dates in output but retain their date time attribute
#>
class BrownserveShortDate
{
    [datetime]$Date

    BrownserveShortDate([datetime]$Date)
    {
        $this.Date = $Date
    }

    BrownserveShortDate([string]$Date)
    {
        $this.Date = $Date
    }

    [string] ToString()
    {
        return "$(Get-Date $this.Date -Format 'yyyy/MM/dd')"
    }
}

<#
    This class helps us to format version history entries from a changelog
#>
class BrownserveVersionHistory
{
    [semver]$Version
    [BrownserveShortDate]$ReleaseDate
    [string]$URL
    [string[]]$ReleaseNotes
    [bool]$PreRelease = $false

    BrownserveVersionHistory([semver]$Version, [datetime]$ReleaseDate, [string]$URL, [string]$ReleaseNotes)
    {
        $this.Version = $Version
        $this.ReleaseDate = $ReleaseDate
        $this.URL = $URL
        $this.ReleaseNotes = $ReleaseNotes
        if ($this.Version.PreReleaseLabel)
        {
            $this.PreRelease = $true
        }
    }

    BrownserveVersionHistory([pscustomobject]$VersionHistory)
    {
        if (!$VersionHistory.Version)
        {
            throw 'Cannot create BrownserveVersionHistory object without a Version'
        }
        if (!$VersionHistory.ReleaseDate)
        {
            throw 'Cannot create BrownserveVersionHistory object without a ReleaseDate'
        }
        if (!$VersionHistory.URL)
        {
            throw 'Cannot create BrownserveVersionHistory object without a URL'
        }
        if (!$VersionHistory.ReleaseNotes)
        {
            throw 'Cannot create BrownserveVersionHistory object without ReleaseNotes'
        }
        $this.Version = $VersionHistory.Version
        $this.ReleaseDate = $VersionHistory.ReleaseDate
        $this.URL = $VersionHistory.URL
        $this.ReleaseNotes = $VersionHistory.ReleaseNotes
        if ($this.Version.PreReleaseLabel)
        {
            $this.PreRelease = $true
        }
    }

    BrownserveVersionHistory([hashtable]$VersionHistory)
    {
        if (!$VersionHistory.Version)
        {
            throw 'Cannot create BrownserveVersionHistory object without a Version'
        }
        if (!$VersionHistory.ReleaseDate)
        {
            throw 'Cannot create BrownserveVersionHistory object without a ReleaseDate'
        }
        if (!$VersionHistory.URL)
        {
            throw 'Cannot create BrownserveVersionHistory object without a URL'
        }
        if (!$VersionHistory.ReleaseNotes)
        {
            throw 'Cannot create BrownserveVersionHistory object without ReleaseNotes'
        }
        $this.Version = $VersionHistory.Version
        $this.ReleaseDate = $VersionHistory.ReleaseDate
        $this.URL = $VersionHistory.URL
        $this.ReleaseNotes = $VersionHistory.ReleaseNotes
        if ($this.Version.PreReleaseLabel)
        {
            $this.PreRelease = $true
        }
    }

    [string] ToString()
    {
        return "$($this.Version) - $($this.ReleaseDate)"
    }
}

<#
    Class for storing Brownserve Changelog data
#>
class BrownserveChangelog
{
    [BrownserveVersionHistory[]]$VersionHistory
    [int]$NewEntryInsertLine
    [BrownserveVersionHistory]$LatestVersion
    hidden [string]$ChangelogPath
    hidden [string[]]$Content
    [bool]$HasPlaceholder

    BrownserveChangelog([BrownserveVersionHistory[]]$VersionHistory, [int]$NewEntryInsertLine, [string]$ChangelogPath, [string[]]$Content)
    {
        $this.VersionHistory = $VersionHistory | Sort-Object -Property ReleaseDate -Descending
        $this.NewEntryInsertLine = $NewEntryInsertLine
        $this.LatestVersion = $this.VersionHistory[0]
        $this.ChangelogPath = $ChangelogPath
        $this.Content = $Content
    }

    BrownserveChangelog([pscustomobject]$Changelog)
    {
        if (!$Changelog.VersionHistory)
        {
            throw 'Cannot create BrownserveChangelog object without VersionHistory'
        }
        if (!$Changelog.NewEntryInsertLine)
        {
            throw 'Cannot create BrownserveChangelog object without NewEntryInsertLine'
        }
        if (!$Changelog.ChangelogPath)
        {
            throw 'Cannot create BrownserveChangelog object without ChangelogPath'
        }
        if (!$Changelog.Content)
        {
            throw 'Cannot create BrownserveChangelog object without Content'
        }
        $this.VersionHistory = $Changelog.VersionHistory | Sort-Object -Property ReleaseDate -Descending
        $this.NewEntryInsertLine = $Changelog.NewEntryInsertLine
        $this.LatestVersion = $this.VersionHistory[0]
        $this.ChangelogPath = $Changelog.ChangelogPath
        $this.Content = $Changelog.Content
        $this.HasPlaceholder = [bool]$Changelog.HasPlaceholder
    }

    BrownserveChangelog([hashtable]$Changelog)
    {
        if (!$Changelog.VersionHistory)
        {
            throw 'Cannot create BrownserveChangelog object without VersionHistory'
        }
        if (!$Changelog.NewEntryInsertLine)
        {
            throw 'Cannot create BrownserveChangelog object without NewEntryInsertLine'
        }
        if (!$Changelog.ChangelogPath)
        {
            throw 'Cannot create BrownserveChangelog object without ChangelogPath'
        }
        if (!$Changelog.Content)
        {
            throw 'Cannot create BrownserveChangelog object without Content'
        }
        $this.VersionHistory = $Changelog.VersionHistory | Sort-Object -Property ReleaseDate -Descending
        $this.NewEntryInsertLine = $Changelog.NewEntryInsertLine
        $this.LatestVersion = $this.VersionHistory[0]
        $this.ChangelogPath = $Changelog.ChangelogPath
        $this.Content = $Changelog.Content
        $this.HasPlaceholder = [bool]$Changelog.HasPlaceholder
    }
}

## IDE / EditorConfig classes

<#
    This class helps us format editorconfig properties
#>
class EditorConfigProperty
{
    [string]$Name
    $Value

    EditorConfigProperty([string]$Name, $Value)
    {
        $this.Name = $Name
        $this.Value = $Value
        $this.ValidityCheck()
    }

    EditorConfigProperty([hashtable]$Property)
    {
        $this.Value = $Property.Value
        $this.Name = $Property.Name
        $this.ValidityCheck()
    }

    EditorConfigProperty([System.Collections.DictionaryEntry]$Property)
    {
        $this.Value = $Property.Value
        $this.Name = $Property.Name
        $this.ValidityCheck()
    }

    [string] ToString()
    {
        return ("$($this.Name) = $($this.Value)").ToLower()
    }

    hidden ValidityCheck()
    {
        $ValidPropertyNames = @(
            'indent_style',
            'indent_size',
            'tab_width',
            'end_of_line',
            'charset',
            'trim_trailing_whitespace',
            'insert_final_newline',
            'max_line_length'
        )
        if ($this.Name -notin $ValidPropertyNames)
        {
            throw "Invalid editorconfig property name: '$($this.Name)'"
        }

        switch ($this.Name)
        {
            'indent_style'
            {
                $ValidValues = @('tab', 'space')
                if ($this.Value -notin $ValidValues)
                {
                    throw "Invalid indent_style value: '$($this.Value)'"
                }
            }
            'indent_size'
            {
                (($this.Value -isnot [int]) -or ($this.Value -isnot [Int64]))
                {
                    if ($this.Value -ne 'tab')
                    {
                        throw "Invalid indent_size value: '$($this.Value)'"
                    }
                }
            }
            'tab_width'
            {
                (($this.Value -isnot [int]) -or ($this.Value -isnot [Int64]))
                {
                    throw "Invalid tab_width value: '$($this.Value)'"
                }
            }
            'end_of_line'
            {
                $ValidValues = @('lf', 'cr', 'crlf')
                if ($this.Value -notin $ValidValues)
                {
                    throw "Invalid end_of_line value: '$($this.Value)'"
                }
            }
            'charset'
            {
                $ValidValues = @('latin1', 'utf-8', 'utf-8-bom', 'utf-16be', 'utf-16le')
                if ($this.Value -notin $ValidValues)
                {
                    throw "Invalid charset value: '$($this.Value)'"
                }
            }
            'trim_trailing_whitespace'
            {
                if ($this.Value -isnot [bool])
                {
                    throw "Invalid trim_trailing_whitespace value: '$($this.Value)'"
                }
            }
            'insert_final_newline'
            {
                if ($this.Value -isnot [bool])
                {
                    throw "Invalid insert_final_newline value: '$($this.Value)'"
                }
            }
            'max_line_length'
            {
                if (($this.Value -isnot [int]) -or ($this.Value -isnot [Int64]))
                {
                    if ($this.Value -ne 'off')
                    {
                        throw "Invalid max_line_length value: '$($this.Value)'"
                    }
                }
            }
        }
    }
}

<#
    This class helps us format editorconfig sections
#>
class EditorConfigSection
{
    [string]$FilePath
    [EditorConfigProperty[]]$Properties
    [string[]]$Comment

    EditorConfigSection([string]$FilePath, [EditorConfigProperty[]]$Properties)
    {
        $this.FilePath = $FilePath
        $this.Properties = $Properties
    }

    EditorConfigSection([string]$FilePath, [EditorConfigProperty[]]$Properties, [string[]]$Comment)
    {
        $this.FilePath = $FilePath
        $this.Properties = $Properties
        $this.Comment = $Comment
    }

    EditorConfigSection([hashtable]$Section)
    {
        if (!$Section.FilePath)
        {
            throw 'Cannot create EditorConfigSection object without FilePath'
        }
        if (!$Section.Properties)
        {
            throw 'Cannot create EditorConfigSection object without Properties'
        }
        if ($Section.Comment)
        {
            $this.Comment = $Section.Comment
        }
        $this.FilePath = $Section.FilePath
        if ($Section.Properties -is [hashtable])
        {
            $this.ExpandProperties($Section.Properties)
        }
        else
        {
            $this.Properties = $Section.Properties
        }
    }

    hidden ExpandProperties([hashtable]$Properties)
    {
        $ExpandedProps = @()
        $Properties.GetEnumerator() | ForEach-Object {
            $ExpandedProps += [EditorConfigProperty]$_
        }
        $this.Properties = $ExpandedProps
    }

    [string] ToString()
    {
        $Return = ''
        if ($this.Comment)
        {
            $this.Comment | ForEach-Object {
                if ($_.StartsWith('#'))
                {
                    $Return += "$_`n"
                }
                else
                {
                    $Return += "# $_`n"
                }
            }
        }
        if ($this.FilePath -notmatch '^\[.*\]$')
        {
            $Return += "[$($this.FilePath)]`n"
        }
        else
        {
            $Return += "$($this.FilePath)`n"
        }
        $this.Properties | ForEach-Object {
            $Return += "$($_)`n"
        }
        return $Return
    }
}

## Git / .gitignore classes

class GitIgnore
{
    [string[]]$Item
    [string]$Comment

    GitIgnore([hashtable]$Hashtable)
    {
        if (!$Hashtable.Item)
        {
            throw "Hashtable does not contain a key named 'Item'"
        }
        $this.Item = $Hashtable.Item
        if ($Hashtable.Comment)
        {
            # Try to ensure every line starts with the pound symbol
            $LocalComment = $Hashtable.Comment -split "`n"
            $SanitizedComment = ""
            $LocalComment | ForEach-Object {
                if ($_ -notmatch '^\#')
                {
                    $SanitizedComment += "# $_"
                }
                else
                {
                    $SanitizedComment += $_
                }
                if ($_ -notmatch $LocalComment[-1])
                {
                    $SanitizedComment += "`n"
                }
            }
            $this.Comment = $SanitizedComment
        }
    }

    GitIgnore([PSCustomObject]$Object)
    {
        if (!$Object.Item)
        {
            throw "Hashtable does not contain a key named 'Item'"
        }
        $this.Item = $Object.Item
        if ($Object.Comment)
        {
            # Try to ensure every line starts with the pound symbol
            $LocalComment = $Object.Comment -split "`n"
            $SanitizedComment = ""
            $LocalComment | ForEach-Object {
                if ($_ -notmatch '^\#')
                {
                    $SanitizedComment += "# $_"
                }
                else
                {
                    $SanitizedComment += $_
                }
                if ($_ -notmatch $LocalComment[-1])
                {
                    $SanitizedComment += "`n"
                }
            }
            $this.Comment = $SanitizedComment
        }
    }

    GitIgnore([string]$Item)
    {
        $this.Item = $Item
    }

    GitIgnore([string]$Item, [string]$Comment)
    {
        $this.Item = $Item
        # Try to ensure every line starts with the pound symbol
        $LocalComment = $Comment -split "`n"
        $SanitizedComment = ""
        $LocalComment | ForEach-Object {
            if ($_ -notmatch '^\#')
            {
                $SanitizedComment += "# $_"
            }
            else
            {
                $SanitizedComment += $_
            }
            if ($_ -notmatch $LocalComment[-1])
            {
                $SanitizedComment += "`n"
            }
        }
        $this.Comment = $SanitizedComment
    }
}

## Build infrastructure classes

class InitPath
{
    [string] $VariableName
    [string] $Path
    [array] $ChildPaths
    [string] $Description
    [string] $PathType

    InitPath([pscustomobject]$InitPath)
    {
        $RequiredProps = @('path','VariableName','PathType')
        foreach ($Prop in $RequiredProps)
        {
            if (!$InitPath.$Prop)
            {
                throw "Object missing property '$Prop'"
            }
            else
            {
                $this.$Prop = $InitPath.$Prop
            }
        }
        if ($InitPath.ChildPaths)
        {
            $this.ChildPaths = $InitPath.ChildPaths
        }
        if ($InitPath.Description)
        {
            $this.Description = $InitPath.Description
        }
    }

    InitPath([hashtable]$InitPath)
    {
        $RequiredKeys = @('path','VariableName','PathType')
        foreach ($Key in $RequiredKeys)
        {
            if (!$InitPath.$Key)
            {
                throw "Hashtable missing property '$Key'"
            }
            else
            {
                $this.$Key = $InitPath.$Key
            }
        }
        if ($InitPath.ChildPaths)
        {
            $this.ChildPaths = $InitPath.ChildPaths
        }
        if ($InitPath.Description)
        {
            $this.Description = $InitPath.Description
        }
    }
}

enum BrownserveCICD
{
    GitHubActions
    TeamCity
}

enum BrownserveRepoProjectType
{
    PowerShellModule
    BrownservePSTools
    WebApp
    Generic
}

class GitHubActionsJob
{
    [string]$JobTitle
    [string]$RunsOn
    [hashtable[]]$Steps

    GitHubActionsJob([hashtable]$Hash)
    {
        $RequiredKeys = @('JobTitle', 'RunsOn', 'Steps')
        foreach ($Key in $RequiredKeys)
        {
            if (!$Hash.$Key)
            {
                throw "Hashtable missing key '$Key'"
            }
            else
            {
                $this.$Key = $Hash.$Key
            }
        }
    }
}

class PaketDependencyRule
{
    [string]$Source
    [string]$PackageName

    PaketDependencyRule([hashtable]$Hashtable)
    {
        $RequiredKeys = @('Source', 'PackageName')
        foreach ($Key in $RequiredKeys)
        {
            if (!$Hashtable.$Key)
            {
                throw "Hashtable missing key '$Key'"
            }
            else
            {
                $this.$Key = $Hashtable.$Key
            }
        }
    }

    PaketDependencyRule([pscustomobject]$Object)
    {
        $RequiredKeys = @('Source', 'PackageName')
        foreach ($Key in $RequiredKeys)
        {
            if (!$Object.$Key)
            {
                throw "Object missing property '$Key'"
            }
            else
            {
                $this.$Key = $Object.$Key
            }
        }
    }
}

class PaketDependency
{
    [PaketDependencyRule[]]$Rule
    [string]$Comment

    PaketDependency([hashtable]$Hashtable)
    {
        if (!$Hashtable.Rule)
        {
            throw "Hashtable missing key 'Rule'"
        }

        $this.Rule = $Hashtable.Rule
        if ($Hashtable.Comment)
        {
            $LocalComment = $Hashtable.Comment -split "`n"
            $SanitizedComment = ''
            $LocalComment | ForEach-Object {
                if ($_ -notmatch '^\#')
                {
                    $SanitizedComment += "# $_"
                }
                else
                {
                    $SanitizedComment += $_
                }
                if ($_ -notmatch $LocalComment[-1])
                {
                    $SanitizedComment += "`n"
                }
            }
            $this.Comment = $SanitizedComment
        }
    }

    PaketDependency([pscustomobject]$Object)
    {
        if (!$Object.Rule)
        {
            throw "Hashtable missing key 'Rule'"
        }

        $this.Rule = $Object.Rule
        if ($Object.Comment)
        {
            $LocalComment = $Object.Comment -split "`n"
            $SanitizedComment = ''
            $LocalComment | ForEach-Object {
                if ($_ -notmatch '^\#')
                {
                    $SanitizedComment += "# $_"
                }
                else
                {
                    $SanitizedComment += $_
                }
                if ($_ -notmatch $LocalComment[-1])
                {
                    $SanitizedComment += "`n"
                }
            }
            $this.Comment = $SanitizedComment
        }
    }
}

class PackageAlias
{
    [string] $Alias
    [string] $FileName
    [string] $VariableName

    PackageAlias([hashtable]$Hash)
    {
        $RequiredKeys = @('Alias','FileName')
        foreach ($Key in $RequiredKeys)
        {
            if (!$Hash.$Key)
            {
                throw "Hashtable missing key '$Key'"
            }
            else
            {
                $this.$Key = $Hash.$Key
            }
        }
        if ($Hash.VariableName)
        {
            $this.VariableName = $Hash.VariableName
        }
    }

    PackageAlias([pscustomobject]$Obj)
    {
        $RequiredProps = @('Alias','FileName')
        foreach ($Prop in $RequiredProps)
        {
            if (!$Obj.$Prop)
            {
                throw "Object missing property '$Prop'"
            }
            else
            {
                $this.$Prop = $Obj.$Prop
            }
        }
        if ($Obj.VariableName)
        {
            $this.VariableName = $Obj.VariableName
        }
    }
}

## VSCode classes

class BrownserveVSCodeExtension
{
    [string]$ExtensionID
    [hashtable]$Settings

    BrownserveVSCodeExtension([hashtable]$Hash)
    {
        $this.ExtensionID = $Hash.ExtensionID
        $this.Settings = $Hash.Settings
    }

    BrownserveVSCodeExtension([string]$ExtensionID, [hashtable]$Hash)
    {
        $this.ExtensionID = $ExtensionID
        $this.Settings = $Hash
    }
}

## PowerShell module classes

class BrownservePowerShellModule
{
    [string]$Name
    [string]$Description
    [guid]$GUID
    [string[]]$Tags
    [string[]]$RequiredModules

    BrownservePowerShellModule([hashtable]$Hashtable)
    {
        $RequiredKeys = @('name','description','guid','tags')
        foreach ($Key in $RequiredKeys)
        {
            $MatchingKey = $Hashtable.Keys | Where-Object { $_ -ieq $Key } | Select-Object -First 1
            if (!$MatchingKey)
            {
                throw "Hashtable missing required key '$Key'"
            }
            $this.$Key = $Hashtable[$MatchingKey]
        }
        $RequiredModulesKey = $Hashtable.Keys | Where-Object { $_ -ieq 'RequiredModules' } | Select-Object -First 1
        if ($RequiredModulesKey)
        {
            $this.RequiredModules = $Hashtable[$RequiredModulesKey]
        }
    }
}
