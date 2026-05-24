---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Get-SPDXLicenseIDs

## SYNOPSIS

Attempts to get the latest SPDX license short ID list.

## SYNTAX

```text
Get-SPDXLicenseIDs [[-Uri] <Uri>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will attempt to get the latest available list of the SPDX license short ID's from GitHub.

## EXAMPLES

### Example 1

```powershell
PS C:\> Get-SPDXLicenseIDs
```

Would return a list of all the currently available SPDX license short ID's.

## PARAMETERS

### -Uri

The URI to use to get the list from, expects JSON.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: (https://raw.githubusercontent.com/spdx/license-list-data/main/json/licenses.json)
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
