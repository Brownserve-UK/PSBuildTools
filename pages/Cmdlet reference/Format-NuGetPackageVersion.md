---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Format-NuGetPackageVersion

## SYNOPSIS

Formats a version number to ensure compatibility with NuGet and nuget.org

## SYNTAX

```text
Format-NuGetPackageVersion [-Version] <SemanticVersion> [[-SemanticVersion] <Version>]
 [<CommonParameters>]
```

## DESCRIPTION

Formats a version number to ensure compatibility with NuGet and nuget.org

## EXAMPLES

### Example 1: Format for SemVer 2.0.0 (NuGet 4.3.0+)

```powershell
Format-NuGetPackageVersion -Version '0.1.2-rc1+20230825'
```

This would return the unedited version string that was passed in as it is completely compatible.

### Example 2: Format for SemVer 1.0.0 (Pre-NuGet 4.0.0)

```powershell
Format-NuGetPackageVersion -Version '0.1.2-rc1+20230825' -SemanticVersion '1.0.0'
```

This would return concatenate the prerelease and build labels as build labels are not supported.
Resulting in `0.1.2-rc120230825` being returned

## PARAMETERS

### -SemanticVersion

The semantic version format to support.  
Prior to NuGet 4.3.0 only SemVer 1.0.0 was supported.

```yaml
Type: Version
Parameter Sets: (All)
Aliases:
Accepted values: 1.0.0, 2.0.0

Required: False
Position: 1
Default value: '2.0.0'
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version

The version to format

```yaml
Type: SemanticVersion
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.SemanticVersion

### System.Version

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
