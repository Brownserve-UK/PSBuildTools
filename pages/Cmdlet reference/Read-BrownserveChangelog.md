---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Read-BrownserveChangelog

## SYNOPSIS

Reads in a changelog file and returns the contents as a custom object.

## SYNTAX

```text
Read-BrownserveChangelog [-ChangelogPath] <String> [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will read in a changelog file and return the contents as a custom object.
The changelog file must be in the standard Brownserve format.

## EXAMPLES

### Example 1

```powershell
Read-BrownserveChangelog -ChangelogPath C:\myRepo\Changelog.md
```

Would read in the changelog file and return a PowerShell object containing the version history and where to insert a new entry.

## PARAMETERS

### -ChangelogPath

The path to the changelog file

```yaml
Type: String
Parameter Sets: (All)
Aliases: Path

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: True
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
