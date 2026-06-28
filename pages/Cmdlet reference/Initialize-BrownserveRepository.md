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
Initialize-BrownserveRepository [[-RepositoryPath] <String>] [-ProjectType <BrownserveRepoProjectType>]
 [-ModuleInfo <BrownservePowerShellModule>] [-RepoName <String>] [-Owner <String>] [-Force]
 [<CommonParameters>]
```

## DESCRIPTION

We typically use our repositories for a common set of purposes (e.g. PowerShell modules, standard builds etc) and this cmdlet will prepare a given repository for use.

## EXAMPLES

### Example 1

```powershell
Initialize-BrownserveRepository -RepositoryPath 'c:\MyPowerShellModule' -ProjectType 'PowerShellModule'
```

This would prepare the repo at 'c:\MyPowerShellModule' for use to store and build a PowerShell module

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

### -ModuleInfo

The PowerShell module metadata, required when repo houses a PowerShell module.

```yaml
Type: BrownservePowerShellModule
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
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

### -ProjectType

The type of project that this repository holds

```yaml
Type: BrownserveRepoProjectType
Parameter Sets: (All)
Aliases:
Accepted values: PowerShellModule, BrownservePSTools, WebApp, RustApp, Generic

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
