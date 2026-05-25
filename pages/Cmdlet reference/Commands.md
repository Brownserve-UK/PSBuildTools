---
Module Name: Brownserve.PSBuildTools
Module Guid: 2752b94a-d020-4696-9e9e-b85de62dc3ca
Download Help Link: https://docs.brownserve.co.uk/Brownserve.PSBuildTools/Cmdlet%20reference/Commands/
Help Version: 0.1.1
Locale: en-US
---

# Brownserve.PSBuildTools Module

## Description

A collection of PowerShell build tools used across various Brownserve projects to aid in CI/CD deployments and module development.

## Brownserve.PSBuildTools Cmdlets

### [Add-BrownserveChangelogEntry](Add-BrownserveChangelogEntry.md)

Inserts a new changelog entry into a given changelog file

### [Add-ModuleHelp](Add-ModuleHelp.md)

Creates XML MALM help for a PowerShell module

### [Build-ModuleDocumentation](Build-ModuleDocumentation.md)

This will build markdown PowerShell module documentation using PlatyPS

### [Format-NuGetPackageVersion](Format-NuGetPackageVersion.md)

Formats a version number to ensure compatibility with NuGet and nuget.org

### [Get-BrownserveRepositoryPaths](Get-BrownserveRepositoryPaths.md)

Returns a list of all paths that are managed for a given repository.

### [Get-SPDXLicenseIDs](Get-SPDXLicenseIDs.md)

Attempts to get the latest SPDX license short ID list.

### [Import-PlatyPSModule](Import-PlatyPSModule.md)

Imports the PlatyPS module avoiding collisions with other modules.

### [Initialize-BrownserveRepository](Initialize-BrownserveRepository.md)

Prepares a repository for use for a given project

### [New-BrownserveChangelogEntry](New-BrownserveChangelogEntry.md)

Creates a new Keep a Changelog entry for a given version in the standard Brownserve format.

### [New-BrownservePowerShellModule](New-BrownservePowerShellModule.md)

Creates a new PowerShell module in the standard Brownserve format

### [New-BrownservePowerShellModuleBuild](New-BrownservePowerShellModuleBuild.md)

Adds the various requirements to build a PowerShell module to a given project/repo.

### [New-SPDXLicense](New-SPDXLicense.md)

Creates a new licence using the SPDX format

### [Read-BrownserveChangelog](Read-BrownserveChangelog.md)

Reads in a changelog file and returns the contents as a custom object.

### [Send-BuildNotification](Send-BuildNotification.md)

Sends a standard Brownserve build notification.

### [Send-SlackNotification](Send-SlackNotification.md)

Sends a notification to a given Slack webhook

### [Update-BrownservePowerShellModule](Update-BrownservePowerShellModule.md)

Updates a given Brownserve PowerShell module to use the latest template.

### [Update-BrownserveRepository](Update-BrownserveRepository.md)

Updates a given repository to use the latest tooling and settings

### [Update-Version](Update-Version.md)

A simple function to increment a semantic version number.
