---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Update-Version

## SYNOPSIS

A simple function to increment a semantic version number.

## SYNTAX

```text
Update-Version [-Version] <SemanticVersion> [-ReleaseType] <String> [[-PreReleaseString] <String>]
 [[-BuildNumber] <String>] [<CommonParameters>]
```

## DESCRIPTION

This function will increment a semantic version number based on the type of release being done.
It will also optionally append a pre-release string and/or a build number.

## EXAMPLES

### Example 1

```powershell
Update-Version -Version '0.1.2' -ReleaseType 'major'
```

This would return `1.0.0`

## PARAMETERS

### -BuildNumber

An optional build number to append to the version number

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -PreReleaseString

An optional pre-release to append to the version number

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ReleaseType

The type of release (major, minor, patch)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version

The current version that should be updated

```yaml
Type: SemanticVersion
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
