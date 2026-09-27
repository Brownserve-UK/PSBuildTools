---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Initialize-BrownserveRepository

## SYNOPSIS

Prepares a repository for use for a given project

## SYNTAX

```text
Initialize-BrownserveRepository [[-RepositoryPath] <String>] -Components <String[]>
 [-ComponentOptions <Hashtable>] [-RepoName <String>] [-Owner <String>] [-Force]
 [<CommonParameters>]
```

## DESCRIPTION

Repositories are described by a set of components (e.g. 'PowerShellModule', 'RustBinary', 'ContainerImage') rather than a single project type. 'Core' is always included automatically. This cmdlet works out what's missing/different compared to what the requested components expect and, if it's safe to do so, creates/updates those files on a dedicated branch. A file the manifest owns that has been manually edited since it was last generated is reported as a conflict and stops the whole run, before any files are written, unless '-Force' is passed.

## EXAMPLES

### Example 1

```powershell
Initialize-BrownserveRepository -RepositoryPath 'c:\MyRustApp' -Components RustBinary
```

This would prepare the repo at 'c:\MyRustApp' for use to store and build a Rust binary application

### Example 2

```powershell
$ModuleInfo = @{ Name = 'Brownserve.Example'; Description = '...'; GUID = (New-Guid); Tags = @('example') }
Initialize-BrownserveRepository -Components PowerShellModule, MkDocs -ComponentOptions @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }
```

This would prepare the current directory for use to store and build a PowerShell module with MkDocs documentation

## PARAMETERS

### -Force

Forces an overwrite of any files that already exist

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

### -Components

The components that should be present in this repository, 'Core' is always included automatically

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComponentOptions

Options for the requested components, keyed by component name

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: @{}
Accept pipeline input: False
Accept wildcard characters: False
```

### -Owner

The owner of the repository, this is used to populate the copyright holder in the licence.

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

### -RepoName

The name of the repository

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

### -RepositoryPath

The path to the repository to configure

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
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
