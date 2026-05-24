---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Import-PlatyPSModule

## SYNOPSIS

Imports the PlatyPS module avoiding collisions with other modules.

## SYNTAX

```text
Import-PlatyPSModule [<CommonParameters>]
```

## DESCRIPTION

Currently the PlatyPS and powershell-yaml modules cannot be loaded at the same time due both requiring the `YAMLDotNet` assembly but attempting to load different versions. This is already fixed in powershell-yaml and should be fixed with V2 of PlatyPS (https://github.com/PowerShell/platyPS/issues/592) but a build has not yet been released that incorporates these changes.  
Therefore for the time being we have custom loaders to ensure the modules are imported and disposed of when finished.

## EXAMPLES

### Example 1

```powershell
PS C:\> Import-PlatyPSModule
```

Would import the PlatyPS module providing powershell-yaml is not currently loaded.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
