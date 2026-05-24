---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Get-BrownserveRepositoryPaths

## SYNOPSIS

Returns a list of all paths that are managed for a given repository.

## SYNTAX

```text
Get-BrownserveRepositoryPaths [-RepositoryPath] <String>
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet will return a list of paths that should be managed for a given repository.
The repository must have been previously initialised with `Initialize-BrownserveRepository`.

## EXAMPLES

### Example 1

```powershell
Get-BrownserveRepositoryPaths -RepositoryPath C:\myRepo\
```

Returns a list of paths that should be managed for the repository at C:\myRepo\

## PARAMETERS

### -RepositoryPath

The path to the repository.

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
