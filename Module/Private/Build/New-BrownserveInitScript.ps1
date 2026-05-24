function New-BrownserveInitScript
{
    [CmdletBinding()]
    param
    (
        # The permanent paths (i.e. those that should always exists)
        [Parameter(
            Mandatory = $true
        )]
        [InitPath[]]
        $PermanentPaths,

        # The ephemeral paths
        [Parameter(
            Mandatory = $true
        )]
        [InitPath[]]
        $EphemeralPaths,

        # If passed will create a block that attempts to load any local/custom PowerShell modules from the "BuildTools" directory
        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'LocalModule'
        )]
        [switch]
        $IncludeBuildToolsDirectoryModuleLoader,

        # If passed will create a block that loads a single module from the "Module" directory
        [Parameter(
            Mandatory = $false,
            ParameterSetName = 'Module'
        )]
        [switch]
        $IncludeModuleLoader,

        # If passed will include our custom powershell-yaml loader
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludePowerShellYaml,

        # If passed will include our custom PlatyPS loader
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludePlatyPS,

        # If passed will include our Invoke-Build/Pester loader
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeBuildTestTools,

        # We restoring packages from Nuget/Paket we may want to set aliases to them to use the local version instead of using the system provided version
        [Parameter(Mandatory = $false)]
        [PackageAlias[]]
        $PackageAliases,

        # Any custom init steps
        [Parameter(
            Mandatory = $false
        )]
        [string]
        $CustomInitSteps
    )
    
    begin
    {
        # Import the template
        try
        {
            $InitTemplate = Get-Content (Join-Path $PSScriptRoot 'templates' init.ps1.template) -Raw
        }
        catch
        {
            throw "Failed to import InitTemplate.`n$($_.Exception.Message)"
        }    
    }
    
    process
    {
        # We'll go over each permanent path and create an entry in the _init file that will resolve the path
        # to it's actual location
        $PermanentPathText = ''
        $PermanentPaths | ForEach-Object {
            # If we have a description we need to have that appear first
            if ($_.Description)
            {
                $PermanentPathText = $PermanentPathText + "# $($_.Description)`n"
            }
            # If we've got child paths we'll have to do some really fancy interpolation
            if ($_.ChildPaths)
            {
                $Path = "-ChildPath '$($_.Path)' -AdditionalChildPath '$($_.ChildPaths | Join-String -Separator "','")'" 
            }
            else
            {
                $Path = "-ChildPath '$($_.Path)'"
            }
            $PermanentPathText = $PermanentPathText + @"
`$Global:$($_.VariableName) = Join-Path `$global:BrownserveRepoRootDirectory $Path | Convert-Path`n
"@
        }
        $InitTemplate = $InitTemplate.Replace('###PERMANENT_PATHS###', $PermanentPathText)

        # For our ephemeral paths we first need to define them as standalone variables, so we can create them
        # if they don't already exist
        $EphemeralDirectoriesText = ''
        $EphemeralFilesText = ''

        $EphemeralDirectories = $EphemeralPaths | Where-Object { $_.PathType -eq 'Directory' }
        $EphemeralFiles = $EphemeralPaths | Where-Object { $_.PathType -eq 'File' }

        if ($EphemeralDirectories)
        {
            $EphemeralDirectories | ForEach-Object -Process {
                # If we've got child paths we'll have to do some really fancy interpolation
                if ($_.ChildPaths)
                {
                    $Path = "-ChildPath '$($_.Path)' -AdditionalChildPath '$($_.ChildPaths | Join-String -Separator "','")'" 
                }
                else
                {
                    $Path = "-ChildPath '$($_.Path)'"
                }
                $EphemeralDirectoriesText = $EphemeralDirectoriesText + @"
    (`$$($_.VariableName) = Join-Path -Path `$global:BrownserveRepoRootDirectory $Path)
"@
                # We are building an array in the template
                # if this is the last line of the array then we don't want to add a comma!
                if ($_ -ne $EphemeralDirectories[-1])
                {
                    $EphemeralDirectoriesText = $EphemeralDirectoriesText + ",`n"
                }
            }
        }

        if ($EphemeralFiles)
        {
            $EphemeralFiles | ForEach-Object -Process {
                # If we've got child paths we'll have to do some really fancy interpolation
                if ($_.ChildPaths)
                {
                    $Path = "-ChildPath '$($_.Path)' -AdditionalChildPath '$($_.ChildPaths | Join-String -Separator "','")'" 
                }
                else
                {
                    $Path = "-ChildPath '$($_.Path)'"
                }
                $EphemeralFilesText = $EphemeralFilesText + @"
    Join-Path -Path `$global:BrownserveRepoRootDirectory $Path
"@
                # We are building an array in the template
                # if this is the last line of the array then we don't want to add a comma!
                if ($_ -ne $EphemeralFiles[-1])
                {
                    $EphemeralFilesText = $EphemeralFilesText + ",`n"
                }
            }
        }
        $InitTemplate = $InitTemplate.Replace('###EPHEMERAL_DIRECTORIES###', $EphemeralDirectoriesText)
        $InitTemplate = $InitTemplate.Replace('###EPHEMERAL_FILES###', $EphemeralFilesText)

        # Now we can create our global variables that reference their proper paths, we only do this for directories as we assume that files will be recreated by whatever created them in the first place
        $EphemeralPathVariableText = "`n"
        $EphemeralDirectories | ForEach-Object {
            # If we have a description we need to have that appear first
            if ($_.Description)
            {
                $EphemeralPathVariableText = $EphemeralPathVariableText + "# $($_.Description)`n"
            }
            $EphemeralPathVariableText = $EphemeralPathVariableText + @"
`$global:$($_.VariableName) = `$$($_.VariableName) | Convert-Path`n
"@
        }
        $InitTemplate = $InitTemplate.Replace('###EPHEMERAL_PATH_VARIABLES###', $EphemeralPathVariableText)

        $ModuleText = ''
        # Here we set up our custom module loader for loading any Powershell modules we may have created in a given repo
        if ($IncludeBuildToolsDirectoryModuleLoader)
        {
            if ($PermanentPaths.VariableName -notcontains 'BrownserveRepoBuildToolsDirectory')
            {
                throw "Cannot use '-IncludeBuildToolsDirectoryModuleLoader' when 'BrownserveRepoBuildToolsDirectory' has not been specified"
            }
            $ModuleText = @'

# Find and load any local PowerShell helper modules/tools that may exist
try
{
    Write-Verbose "Checking '$($global:BrownserveRepoBuildToolsDirectory)' for any PowerShell modules to load'
    Get-ChildItem $global:BrownserveRepoBuildToolsDirectory -Filter '*.psm1' -Recurse | Foreach-Object {
        Import-Module $_ -Force -Verbose:$false
    }
}
catch
{
    throw "Failed to import local modules.`n$($_.Exception.Message)"
}

'@
        }
        # Alternatively the repo may contain a single module, in which case we load that
        if ($IncludeModuleLoader)
        {
            if ($PermanentPaths.VariableName -notcontains 'BrownserveModuleDirectory')
            {
                throw "Cannot use 'IncludeModuleLoader' when 'BrownserveModuleDirectory' has not been specified"
            }
            $ModuleText = @'

# Load the module from the "Module" directory
try
{
    Write-Verbose "Loading module from '$($Global:BrownserveModuleDirectory)'"
    Get-ChildItem $Global:BrownserveModuleDirectory -Filter '*.psm1' -Recurse | Foreach-Object {
        Import-Module $_ -Force -Verbose:$false
    }
}
catch
{
    throw "Failed to import module.`n$($_.Exception.Message)"
}

'@
        }
        # Add in any custom module loaders we're using
        $InitTemplate = $InitTemplate.Replace('###MODULE_LOADER###', $ModuleText)

        $CustomExternalTooling = ''
        if ($IncludePlatyPS -or $IncludePowerShellYaml)
        {
            $CustomExternalTooling += @"

# The PackageManagement module needs to be loaded for Save-Module to function without being overly verbose
if (!(Get-Module 'PackageManagement'))
{
    try
    {
        Import-Module 'PackageManagement' -ErrorAction 'Stop' -Verbose:`$False
    }
    catch
    {
        throw "Failed to import the 'PackageManagement' module.`$(`$_.Exception.Message)"
    }
}`n`n
"@
        }

        if ($IncludePlatyPS)
        {
            $CustomExternalTooling += @"
<#
    Some cmdlets make use of the platyPS module so ensure it is available
    Unfortunately due to https://github.com/PowerShell/platyPS/issues/592 we cannot load this at the same time as powershell-yaml.
    This should be fixed in a later v2 release but v2 is incredibly buggy at the moment and often fails with unhelpful errors.
    So we download the module and set a special variable to its path.
#>
try
{
    Write-Verbose 'Downloading platyPS module'
    Save-Module 'platyPS' -Repository PSGallery -Path `$Global:BrownserveRepoNugetPackagesDirectory -ErrorAction 'Stop'
    # DON'T import the module, set a well known variable that we can use later on.
    `$Global:BrownserveRepoPlatyPSPath = Get-ChildItem (Join-Path `$Global:BrownserveRepoNugetPackagesDirectory -ChildPath 'platyPS') -Filter 'platyPS.psd1' -Recurse
    if (!`$Global:BrownserveRepoPlatyPSPath)
    {
        throw 'Failed to find downloaded PlatyPS'
    }
}
catch
{
    throw "Failed to download the platyPS module.``n`$(`$_.Exception.Message)"
}`n`n
"@
        }

        if ($IncludePowerShellYaml)
        {
            $CustomExternalTooling += @"
# Some cmdlets make use of the powershell-yaml module so ensure it is available, we don't auto-load it to avoid clashing with platyPS
try
{
    Write-Verbose 'Downloading powershell-yaml module'
    Save-Module 'powershell-yaml' -Repository PSGallery -Path `$Global:BrownserveRepoNugetPackagesDirectory -ErrorAction 'stop'
    `$Global:BrownserveRepoPowerShellYAMLPath = Get-ChildItem (Join-Path `$Global:BrownserveRepoNugetPackagesDirectory -ChildPath 'powershell-yaml') -Filter 'powershell-yaml.psd1' -Recurse
    if (!`$Global:BrownserveRepoPowerShellYAMLPath)
    {
        throw 'Failed to find powershell-yaml module after download'
    }
}
catch
{
    throw "Failed to download the powershell-yaml module.``n`$(`$_.Exception.Message)"
}`n`n
"@
        }

        if ($IncludeBuildTestTools)
        {
            $CustomExternalTooling += @"
# This repo makes use of Invoke-Build/Pester to run our builds so we need to import them.
try
{
    # Both modules should have been grabbed from nuget by paket, we simply need to import them
    Write-Verbose 'Importing Invoke-Build'
    Join-Path `$Global:BrownserveRepoNugetPackagesDirectory 'Invoke-Build' -AdditionalChildPath 'tools', 'InvokeBuild.psd1' | Import-Module -Force -Verbose:`$false
    Write-Verbose 'Importing Pester'
    Join-Path `$Global:BrownserveRepoNugetPackagesDirectory 'Pester' -AdditionalChildPath 'tools', 'Pester.psd1' | Import-Module -Force -Verbose:`$False
}
catch
{
    throw "Failed to import build/test modules.``n`$(`$_.Exception.Message)"
}`n`n
"@
        }

        # Add in any external tooling we may be using
        $InitTemplate = $InitTemplate.Replace('###EXTERNAL_TOOLING###', $CustomExternalTooling)

        $PackageAliasText = ''
        if ($PackageAliases)
        {
            $PackageAliasText += @"
<#
    Sometimes packages we install from Paket/NuGet may already exist on the system, so we set aliases to ensure we only use the local versions
    However aliases are only recognised by _this_ PowerShell session, so if we start another process or call a native command then it won't work.
    Therefore we can choose to set a Global variable that we can use to pass to child processes
#>
try
{
"@
            $PackageAliases | ForEach-Object {
                $PackageAliasText += @"
    `$Path = Get-ChildItem `$global:BrownserveRepoNugetPackagesDirectory -Recurse -Filter '$($_.FileName)'
    if (!`$Path)
    {
        throw "Failed to find local path to '$($_.FileName)'"
    }
    if (`$Path.Count -gt 1)
    {
        throw "Too many paths returned for '$($_.FileName)' expected 1, got `$(`$Path.Count)"
    }
    Set-Alias -Name '$($_.Alias)' -Value `$Path -Scope Global`n
"@
                if ($_.VariableName)
                {
                    $PackageAliasText += "    `$Global:$($_.VariableName) = (Get-Command '$($_.Alias)').Definition`n"
                }
                else
                {
                    $PackageAliasText += "`n"
                }
            }
            $PackageAliasText += @"
}
catch
{
    throw "Failed to set aliases.``n`$(`$_.Exception.Message)"
}`n`n
"@
        }
        $InitTemplate = $InitTemplate.Replace('###PACKAGE_ALIASES###', $PackageAliasText)
        # Carry over any custom _init steps if the user has given them
        $InitTemplate = $InitTemplate.Replace('###CUSTOM_INIT_STEPS###', $CustomInitSteps)

        <#
            Finally ensure the content is formatted correctly ready to be written to disk.
        #>
        $InitTemplate = $InitTemplate | Format-BrownserveContent
    }
    end
    {
        Return $InitTemplate
    }
}
