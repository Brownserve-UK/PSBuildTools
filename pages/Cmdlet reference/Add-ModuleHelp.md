---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Add-ModuleHelp

## SYNOPSIS

Creates XML MALM help for a PowerShell module

## SYNTAX

```text
Add-ModuleHelp [-ModuleDirectory] <String> [[-HelpLanguage] <String>] [-DocumentationPath] <String>
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet acts as a wrapper for PlatyPS that will take generated markdown help for a module and convert it into MALM based XML help within the module itself meaning it will work with things like `Get-Help`

## EXAMPLES

### Example 1

```powershell
Add-ModuleHelp -ModuleDirectory './Module' -DocumentationPath './.docs/Brownserve.PSTools'
```

Would convert the markdown documentation located in `./.docs/Brownserve.PSTools` and convert it to MALM based help for the module located in `./Module`

## PARAMETERS

### -DocumentationPath

The path to where the markdown based documentation lives

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

### -HelpLanguage

The language of the documentation

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: en-US
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ModuleDirectory

The path to where the module is located

```yaml
Type: String
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

### System.String

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
