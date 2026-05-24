---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Update-BrownservePowerShellModule

## SYNOPSIS

Updates a given Brownserve PowerShell module to use the latest template.

## SYNTAX

```text
Update-BrownservePowerShellModule [-Path] <String> [-Force]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will update a given PowerShell module that uses our standard Brownserve format to use the latest template while attempting to maintain any customisations the user has made.

## EXAMPLES

### Example 1

```powershell
PS C:\> Update-BrownservePowerShellModule -Path C:\Brownserve.PSTools.psm1
```

This would update the module at the given path.

## PARAMETERS

### -Force

Forcefully overwrite the module even if no changes are detected or if the customisations would be lost.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

The path to the module.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
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
