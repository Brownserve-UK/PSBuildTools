---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# New-BrownserveCIConfiguration

## SYNOPSIS

Generates the CI workflow files for a repository's components.

## SYNTAX

```text
New-BrownserveCIConfiguration [-Provider] <BrownserveCICD> [[-Components] <String[]>]
 [[-ComponentOptions] <Hashtable>] [-RepoName] <String> [[-Owner] <String>]
 [<CommonParameters>]
```

## DESCRIPTION

Resolves the requested components and describes what CI has to do for them (which jobs run on a pull request, what staging and releasing need, the secrets and permissions involved) without tying it to a provider. That description is then turned into workflow files for the chosen provider. Only 'GitHubActions' is implemented, its workflows are thin callers of the reusable workflows in Brownserve-UK/actions, pinned by commit SHA. Any other provider throws. Nothing is written to disk. Each file is returned as an object with a 'Path' (relative to the repository root, using forward slashes) and its 'Content'.

## EXAMPLES

### Example 1

```powershell
New-BrownserveCIConfiguration -Provider GitHubActions -Components RustBinary, ContainerImage -ComponentOptions @{ ContainerImage = @{ Context = 'image' } } -RepoName 'bsdev'
```

Returns the workflow files for a repository that builds a Rust binary and a container image.

### Example 2

```powershell
$ModuleInfo = @{ Name = 'Brownserve.Example'; Description = '...'; GUID = (New-Guid); Tags = @('example') }
New-BrownserveCIConfiguration -Provider GitHubActions -Components PowerShellModule, MkDocs -ComponentOptions @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } } -RepoName 'Brownserve.Example'
```

Returns the workflow files for a PowerShell module repository with MkDocs documentation.

## PARAMETERS

### -ComponentOptions

Options for the requested components, keyed by component name. For example, a 'PowerShellModule' repository's metadata is supplied via '@{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }'.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: @{}
Accept pipeline input: False
Accept wildcard characters: False
```

### -Components

The components the repository is configured with. 'Core' is always included and should not be listed explicitly.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: @()
Accept pipeline input: False
Accept wildcard characters: False
```

### -Owner

The account that owns the repository. Not currently used by the GitHubActions provider, as the generated 'build.ps1' already carries the owner.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: Brownserve-UK
Accept pipeline input: False
Accept wildcard characters: False
```

### -Provider

The CI/CD provider to generate configuration for.

```yaml
Type: BrownserveCICD
Parameter Sets: (All)
Aliases:
Accepted values: GitHubActions, TeamCity

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepoName

The name of the repository, used as the checkout path and as the GitHub repository name passed to the build.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
