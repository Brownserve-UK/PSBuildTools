---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Build-ModuleDocumentation

## SYNOPSIS

This will build markdown PowerShell module documentation using PlatyPS

## SYNTAX

```text
Build-ModuleDocumentation [-ModuleName] <String> [-ModulePath] <String> [-DocumentationPath] <String>
 [-ReloadModule] [-IncludeDontShow] [[-ModuleGUID] <Guid>] [[-HelpVersion] <SemanticVersion>]
 [-NoModuleSubdirectory] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet acts as a sort of wrapper for PlatyPS so that we can easily create PowerShell module documentation for some of our more complicated modules.  
We oftentimes have very specific PowerShell modules in our repos that could do with well written documentation and this cmdlet serves to facilitate that by making it easy to add PlatyPS documentation for any of these modules.  
We also have a handful of modules that we post to NuGet/AzDo and it's very important to ensure these are also well documented.

## EXAMPLES

### EXAMPLE 1

```powershell
Build-ModuleDocumentation -ModuleName 'Brownserve.PSTools' -ModulePath './Module/Brownserve.PSTools.psm1' -DocumentationPath './.docs'
```

This would build the markdown documentation for the `Brownserve.PStools` module in the `.docs/Brownserve.PSTools` directory.

## PARAMETERS

### -DocumentationPath

The directory that the markdown documentation should be stored in

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HelpVersion

The version number of the help.  
Ideally this should match the version of the module being shipped.

```yaml
Type: SemanticVersion
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -IncludeDontShow

If passed will include parameters marked as "DontShow" in documentation.
This is usually undesirable but may be needed if you wish document some complicated logic.

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

### -ModuleGUID

The GUID of the module (if desired)

```yaml
Type: Guid
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleName

The name of the module to have the help created for

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

### -ModulePath

The path to the module

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

### -NoModuleSubdirectory

If passed, the documentation will be generated without creating a subdirectory for the module.

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

### -ReloadModule

Whether or not to force a reload of the module if it's already loaded

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Management.Automation.SemanticVersion

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
