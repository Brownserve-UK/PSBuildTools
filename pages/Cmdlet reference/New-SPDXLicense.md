---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# New-SPDXLicense

## SYNOPSIS

Creates a new licence using the SPDX format

## SYNTAX

```text
New-SPDXLicense [-LicenseType] <String> [-Owner] <String> [[-Year] <Int32>]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will create a new licence file using the SPDX format. This is a standardised format for licences that can be used in a variety of projects.
Currently only the MIT licence is supported.

## EXAMPLES

### Example 1

```powershell
New-SPDXLicense -LicenseType 'MIT' -Owner 'Brownserve'
```

This would return the MIT licence with the copyright holder set to Brownserve.

## PARAMETERS

### -LicenseType

The type of licence to create. (Currently only MIT is supported)

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Accepted values: MIT

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Owner

The owner of the licence, this is used to populate the copyright holder in the licence.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Year

The year to use in the licence, if not specified the current year will be used.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
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
