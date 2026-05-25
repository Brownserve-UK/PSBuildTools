---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# New-BrownservePowerShellModule

## SYNOPSIS

Creates a new PowerShell module in the standard Brownserve format

## SYNTAX

```text
New-BrownservePowerShellModule [-ModuleName] <String> [[-Path] <String>] [[-Description] <String>]
 [-Customisations <String>] [-RequirePowerShellVersion <String>] [-IncludeTemporaryLocationLogic <Boolean>]
 [-IncludeBrownserveCmdletsLogic <Boolean>] [-Force] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will create a new PowerShell module in the standard Brownserve format. This includes the standard Brownserve header, and the Brownserve cmdlets logic. The module will be created in the specified path, with the specified name and description. The module will also include any customisations that you provide.

## EXAMPLES

### Example 1

```powershell
PS C:\> New-BrownservePowerShellModule `
    -Path c:\temp\TestModule `
    -Name 'TestModule' `
    -Description 'My amazing module' `
    -Customisations '$foo = "bar"'
```

This would create a new module in the C:\temp\TestModule folder called `TestModule.psm1` with the supplied description and custom code.

## PARAMETERS

### -Customisations

Any custom code you want to provide to the module, this can always be added later after the module has been created.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Customizations

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description

The description of the module, used to fill out the description heading.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force

If the module already exists then this will forcefully overwrite the module.

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

### -IncludeBrownserveCmdletsLogic

If set to true will include the logic for exporting the list of cmdlets in the module to the `Global:BrownserveCmdlets` variable.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeTemporaryLocationLogic

If set to true will include the logic for setting up a temporary location for the module to use for storing temporary files.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleName

The name of the module to be created.

```yaml
Type: String
Parameter Sets: (All)
Aliases: name

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

The path to where the module will be saved (must be a directory)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RequirePowerShellVersion

If provided this will add a requirement for the specified version of PowerShell.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
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
