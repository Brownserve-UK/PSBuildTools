---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# New-BrownservePowerShellModuleBuild

## SYNOPSIS

Adds the various requirements to build a PowerShell module to a given project/repo.

## SYNTAX

```text
New-BrownservePowerShellModuleBuild [-CICDProvider] <BrownserveCICD> [-ModuleInfo] <BrownservePowerShellModule>
 [-RepoPath] <String> [[-RepoName] <String>] [<CommonParameters>]
```

## DESCRIPTION

Adds the various requirements to build a PowerShell module to a given project/repo

## EXAMPLES

### Example 1

```powershell
New-BrownservePowerShellModuleBuild -CICDProvider 'GitHubActions' -RepoPath 'C:\myPowerShellModule' -ModuleInfo 'C:\myPowerShellModule\ModuleInfo.json'
```

Would create the various files require to build a PowerShell module at the given repo

## PARAMETERS

### -CICDProvider

The CICD provider that will be used with this project.

```yaml
Type: BrownserveCICD
Parameter Sets: (All)
Aliases:
Accepted values: GitHubActions, TeamCity

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleInfo

The modules info

```yaml
Type: BrownservePowerShellModule
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepoName

The name of the repo (if different to the directory provided to -RepoPath)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepoPath

The path to the repository

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Object

## NOTES

## RELATED LINKS
