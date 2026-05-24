---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# Update-BrownserveRepository

## SYNOPSIS

Updates a given repository to use the latest tooling and settings

## SYNTAX

```text
Update-BrownserveRepository [[-RepositoryPath] <String>] [-Owner <String>] [-Force] [-RepoName <String>]
 [<CommonParameters>]
```

## DESCRIPTION

This cmdlet can be used after a repository has been initialised using the `Initialize-BrownserveRepository` cmdlet to keep the projects tooling and settings up to date.

## EXAMPLES

### Example 1

```powershell
Update-BrownserveRepository -RepositoryPath 'C:\myPowershellModule' -ProjectType 'PowerShellModule'
```

Would update the project at 'C:\myPowershellModule'

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

The path to the repository to update

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
