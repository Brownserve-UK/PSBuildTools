---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Add-BrownserveChangelogEntry

## SYNOPSIS

Inserts a new changelog entry into a given changelog file

## SYNTAX

```text
Add-BrownserveChangelogEntry [[-ChangelogPath] <String>] [-NewContent] <String>
 [<CommonParameters>]
```

## DESCRIPTION

Inserts a new changelog entry into a given changelog file.
You can pipe new content directly into this cmdlet from Read-Changelog for ease of use.

## EXAMPLES

### Example 1

```powershell
Add-BrownserveChangelogEntry -ChangelogPath C:\CHANGELOG.md -NewContent "This is a test"
```

Would enter the value "This is a test" at the top of the changelog located at `C:\CHANGELOG.md`

## PARAMETERS

### -ChangelogPath

The path to the changelog file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: True
```

### -NewContent

The content to be inserted into the changelog

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

### BrownserveChangelog

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
