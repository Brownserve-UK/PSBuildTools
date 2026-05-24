---
external help file: Brownserve.PSBuildTools-help.xml
Module Name: Brownserve.PSBuildTools
online version:
schema: 2.0.0
---

# New-BrownserveChangelogEntry

## SYNOPSIS

Creates a new Keep a Changelog entry for a given version in the standard Brownserve format.

## SYNTAX

```text
New-BrownserveChangelogEntry [[-ChangelogPath] <String>] [-Version] <SemanticVersion> -RepositoryOwner <String>
 -RepositoryName <String> [-GitHubToken <String>] [-Notice <String>] [-BreakingChanges <String[]>]
 [-Added <String[]>] [-Fixed <String[]>] [-Deprecated <String[]>] [-Removed <String[]>] [-Changed <String[]>]
 [-Security <String[]>] [-Auto] [-SinceVersion <SemanticVersion>]
 [<CommonParameters>]
```

## DESCRIPTION

Generates a new changelog entry following the Keep a Changelog standard.
Providing the -Auto parameter causes the cmdlet to query merged GitHub pull requests since
the last release and categorise them into sections (Breaking Changes, Added, Fixed,
Deprecated, Removed, Changed, Security) based on their GitHub labels.
PRs labelled 'cicd' are excluded from the changelog.
PRs labelled 'removed' appear in
both the Breaking Changes and Removed sections.
All other PRs with a 'breaking' label
appear only in Breaking Changes.

## EXAMPLES

### Example 1: Automatically generate a changelog entry

```powershell
New-BrownserveChangelogEntry -RepositoryOwner "Brownserve-UK" -RepositoryName "Brownserve.PSTools" -Version 1.0.0 -Auto -GitHubToken $GitHubToken
```

This would generate a changelog entry for version 1.0.0 of the Brownserve.PSTools repository, automatically populating the features, bugfixes and known issues

## PARAMETERS

### -Added

New additions to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Auto

Attempt to automatically populate the entry from merged PRs and their labels

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -BreakingChanges

Breaking changes to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Changed

Backwards-compatible changes to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ChangelogPath

The path to the changelog file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Join-Path $PWD 'CHANGELOG.md')
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: True
```

### -Deprecated

Deprecations to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Fixed

Bug fixes to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -GitHubToken

The GitHub token to use for API calls (required when using -Auto)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Notice

An optional notice to attach to this release

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Removed

Removed features to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -RepositoryName

The name of the repo that the changelog belongs to

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -RepositoryOwner

The owner of the repo that the changelog belongs to

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Security

Security fixes to include (manual override, used without -Auto)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -SinceVersion

The version to treat as the baseline when collecting merges.
Defaults to the most recent changelog entry, but pass the last stable version here
when promoting a pre-release to stable so all changes since the stable release are included.

```yaml
Type: SemanticVersion
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version

The version number to use for the new entry

```yaml
Type: SemanticVersion
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
