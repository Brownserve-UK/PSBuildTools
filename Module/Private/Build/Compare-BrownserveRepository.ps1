<#
.SYNOPSIS
    Checks the current state of a repository to see if it is initialised correctly.
.DESCRIPTION
    This cmdlet is pretty complex as we use it to test the state of a given repository on disk to see if it is
    correctly initialised depending on the type of project the repository houses.
    We don't want to modify any files on disk until we're sure we won't destroy any manual changes that may have
    been made.
    As such this cmdlet will compare the state of the files in the repository to a set of templates that we
    generate based on the type of project the repository houses, if the repository is missing any files or if
    the files are different to that of the templates then we'll add them to a list of files that need to be
    created or updated and return them to the calling process to be handled.
    Due to the complexities of comparing files with line endings and formatting we make heavy use of the various
    "*-BrownserveContent" cmdlets to ensure that we can accurately compare the files.
#>
function Compare-BrownserveRepository
{
    [CmdletBinding()]
    param
    (
        # The path to the repository
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $RepositoryPath,

        # The owner of the repository
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve',

        # The type of build that should be installed in this repo
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [BrownserveRepoProjectType]
        $ProjectType = 'generic',

        # The PowerShell module metadata, required when ProjectType is 'PowerShellModule' or 'BrownservePSTools'
        [Parameter(Mandatory = $false)]
        [BrownservePowerShellModule]
        $ModuleInfo,

        # The GitHub repository name, if different from the local directory name.
        # Defaults to the leaf name of RepositoryPath if not provided.
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName,

        # Forces the recreation of files even if they already exist
        [Parameter(Mandatory = $false)]
        [switch]
        $Force,

        # The config file to use for setting our .gitignore content
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $GitIgnoreConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'gitignore_config.json'),

        # The config file to use for setting our .gitignore content
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $PaketDependenciesConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'paket_dependencies_config.json'),

        # The config file to use that stores our permanent/ephemeral path configuration
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $RepositoryPathsConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'repository_paths_config.json'),

        # The config file that stores devcontainer configurations
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $DevcontainerConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'devcontainer_config.json'),

        # The config file that stores VS Code extension configuration
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $VSCodeExtensionsConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'repository_vscode_extensions.json'),

        # The config file that stores any package aliases we'd like to create
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $PackageAliasConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'package_aliases_config.json'),

        # The config file that stores any editorconfig settings we'd like to create
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $EditorConfigConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'editorconfig_config.json'),

        # The config file that stores markdownlint settings
        [Parameter(Mandatory = $false, DontShow)]
        [string]
        $MarkdownlintConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'markdownlint_config.json')
    )
    begin
    {
        # Ensure that dotnet is available for us to use, we need it to instal tooling and make our nuget.config
        try
        {
            $RequiredTools = @('dotnet')
            Write-Verbose 'Checking for required tooling'
            Assert-Command $RequiredTools

            # Just having dotnet isn't enough, we need to ensure at least one SDK is installed
            # Otherwise `dotnet new` won't work
            $DotNetSDKs = & dotnet --list-sdks
            if (-not $DotNetSDKs)
            {
                throw "No .NET SDKs are installed. Please install a .NET SDK to continue."
            }
        }
        catch
        {
            throw "$($_.Exception.Message)`nThese tools are required to configure a Brownserve repository."
        }

        # Ensure the config files are valid
        try
        {
            $GitIgnoreConfig = Read-ConfigurationFromFile $GitIgnoreConfigFile
            $PaketDependenciesConfig = Read-ConfigurationFromFile $PaketDependenciesConfigFile
            $RepositoryPathsConfig = Read-ConfigurationFromFile $RepositoryPathsConfigFile
            $DevcontainerConfig = Read-ConfigurationFromFile $DevcontainerConfigFile
            $PackageAliasConfig = Read-ConfigurationFromFile $PackageAliasConfigFile
            # Load VS code extensions as a hashtable so we can easily merge things later on
            $VSCodeExtensionsConfig = Read-ConfigurationFromFile $VSCodeExtensionsConfigFile -AsHashtable
            # Load EditorConfig as a hashtable as our [EditorConfigSection] type cannot process psobject's
            $EditorConfigConfig = Read-ConfigurationFromFile $EditorConfigConfigFile -AsHashtable
            $MarkdownlintConfig = Read-ConfigurationFromFile $MarkdownlintConfigFile
        }
        catch
        {
            throw "Failed to import configuration data.`n$($_.Exception.Message)"
        }
    }
    process
    {
        # Ensure we have a valid repository path
        Assert-Directory $RepositoryPath -ErrorAction 'Stop'

        <#
            The point of this cmdlet is to check the state of a given repository and ensure it's configured correctly.
            Therefore we can end up in a few different states:
                - The repository is already configured correctly
                - The repository is missing some files
                - Some managed files exist but require updating/changing
                - Some managed files already exist but are in a format we can't parse (likely manually created or modified)
        #>
        $UnParsableFiles = @()
        $MissingFiles = @()
        $ChangedFiles = @()
        $MissingDirectories = @()
        $IncludeChangelog = $false
        $IncludeWorkflows = $false
        $IncludeMarkdownlint = $false
        $IncludeDependabot = $false
        $IncludeLabelPR = $false
        $IncludeBuildScripts = $false
        $IncludeHelpTests = $false
        $BuildScriptUseWorkingCopyOption = $false

        <#
            We type constrain these variables to ensure that we can easily add to them later on.
            In the past certain operations had a tendency to return a single string rather than an array of strings
            Which would cause issues when we converted them to JSON.
        #>
        [array]$VSCodeWorkspaceExtensionIDs = @()
        $VSCodeWorkspaceSettings = [ordered]@{}

        <#
            Our config file contains a list of permanent paths that should always be created in a repository.
            They survive between init's and are not gitignored.
        #>
        $DefaultPermanentPaths = $RepositoryPathsConfig.Defaults.PermanentPaths

        <#
            Our config file may contain a list of ephemeral paths that get created when the _init script is run.
            They are deleted between init's and are commonly gitignored.
        #>
        $DefaultEphemeralPaths = $RepositoryPathsConfig.Defaults.EphemeralPaths

        if ($DefaultPermanentPaths.VariableName -notcontains 'BrownserveRepoBuildDirectory')
        {
            throw 'BrownserveRepoBuildDirectory path not found in repository paths config file.'
            #TODO: Should we consider raising this as a warning instead?
        }
        $BuildDirectory = Join-Path $RepositoryPath ($DefaultPermanentPaths | Where-Object { $_.VariableName -eq 'BrownserveRepoBuildDirectory' }).Path

        <#
            The below paths will always be required regardless of the type of repository we're working with.
        #>
        $ManifestPath = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        $InitPath = Join-Path $BuildDirectory '_init.ps1'
        $PaketDependenciesPath = Join-Path $RepositoryPath 'paket.dependencies'
        $dotnetToolsConfigPath = Join-Path $RepositoryPath '.config'
        $dotnetToolsPath = Join-Path $dotnetToolsConfigPath 'dotnet-tools.json'
        $NugetConfigPath = Join-Path $RepositoryPath 'nuget.config'
        $GitIgnorePath = Join-Path $RepositoryPath '.gitignore'

        # These paths may or may not be required depending on the type of repository we're working with
        $VSCodePath = Join-Path $RepositoryPath '.vscode'
        $VSCodeExtensionsFilePath = Join-Path $VSCodePath 'extensions.json'
        $VSCodeWorkspaceSettingsFilePath = Join-Path $VSCodePath 'settings.json'
        $DevcontainerDirectoryPath = Join-Path $RepositoryPath '.devcontainer'
        $DevcontainerPath = Join-Path $DevcontainerDirectoryPath 'devcontainer.json'
        $DockerfilePath = Join-Path $DevcontainerDirectoryPath 'Dockerfile'
        $EditorConfigPath = Join-Path $RepositoryPath '.editorconfig'
        $MarkdownlintConfigPath = Join-Path $RepositoryPath '.markdownlint.json'
        $ChangelogPath = Join-Path $RepositoryPath 'CHANGELOG.md'
        $LicensePath = Join-Path $RepositoryPath 'LICENSE'
        $GitHubDirectory = Join-Path $RepositoryPath '.github'
        $WorkflowDirectory = Join-Path $GitHubDirectory 'workflows'
        $BuildDirectory = Join-Path $RepositoryPath '.build'
        $BuildTasksDirectory = Join-Path $BuildDirectory 'tasks'

        <#
            To help with consistency we store a special manifest file in the repository that contains some basic information
            about the repository. (Right now we just use it to store the type of repository we're working with.)
        #>
        if ((Test-Path $ManifestPath))
        {
            Write-Verbose "Found existing repository manifest file at '$ManifestPath'"
            try
            {
                $CurrentManifest = Get-Content -Path $ManifestPath -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
            }
            catch
            {
                throw "Failed to read repository manifest file.`n$($_.Exception.Message)"
            }

            # Check to see if the repository type is the same as the one we're trying to configure, if it's not
            # then fail unless -Force has been passed.
            if (($CurrentManifest.RepositoryType -ne $ProjectType) -and !$Force)
            {
                throw "Repository type mismatch. Expected '$ProjectType' but repository was previously configured as '$($CurrentManifest.RepositoryType)'.`nUse the '-Force' switch to overwrite the existing configuration."
            }
            # Fail if the repository type is not present in the manifest file
            if (!$CurrentManifest.RepositoryType)
            {
                throw 'Repository type not found in manifest file.'
            }
            Write-Debug "Repository type found in manifest file: $($CurrentManifest.RepositoryType)"
        }


        <#
            Because we don't want to make any changes to the repository until we're sure we can do so safely,
            we'll create a temporary directory to stage all our files in.
        #>
        try
        {
            $TempDir = New-BrownserveTemporaryDirectory
        }
        catch
        {
            throw "Failed to create temporary directory.`n$($_.Exception.Message)"
        }

        <#
            We often recommend the use of various VS Code extensions with our projects. There may already
            be some settings in the repo as well, we should try and preserve those as best we can.
            N.B If the extensions.json file only contains a single key then it will be read as a string rather than an array
            so we use the += operator to ensure that we always end up adding any items to the array we created above.
        #>
        try
        {
            $VSCodeWorkspaceExtensionIDs += Get-VSCodeWorkspaceExtensions -WorkspacePath $RepositoryPath -ErrorAction 'Stop'
        }
        catch [BrownserveFileNotFound]
        {
            <#
                Repo probably doesn't have the extensions.json file yet
                Don't terminate as this is expected behaviour.
            #>
            Write-Verbose 'No VS Code extensions.json file found, using the empty array'
        }
        catch
        {
            throw "Failed to get existing recommended extensions.`n$($_.Exception.Message)"
        }

        try
        {
            $VSCodeWorkspaceSettings = Get-VSCodeWorkspaceSettings -WorkspacePath $RepositoryPath -ErrorAction 'Stop'
        }
        catch [BrownserveFileNotFound]
        {
            Write-Verbose 'No VS Code settings.json file found, using the empty dictionary'
            <#
                Repo probably doesn't have the settings.json file yet, We'll use the empty dictionary
                we created above.
            #>
        }
        catch
        {
            throw "Failed to get existing VS Code settings.`n$($_.Exception.Message)"
        }

        <#
            Check for the presence of any managed files in the repo, they may already exist if this repo has been configured before.
            They may contain manual entries that we should try and preserve.
            However it's also entirely possible that these files were created before we started using this cmdlet and
            they may not be in a format we can parse, if this is the case we'll add them to the list of unparsable files.
        #>
        if (Test-Path $GitIgnorePath)
        {
            Write-Verbose 'Parsing existing .gitignore file.'
            try
            {
                $CurrentGitIgnores = Get-BrownserveContent -Path $GitIgnorePath -ErrorAction 'Stop'
                $ManualGitIgnores = $CurrentGitIgnores |
                    Select-BrownserveContent -After '## Manually defined ignores: ##' -FailIfNotFound
            }
            catch
            {
                $UnParsableFiles += $GitIgnorePath
            }
        }
        # Similarly for paket packages
        if (Test-Path $PaketDependenciesPath)
        {
            Write-Verbose 'Parsing existing paket.dependencies file.'
            try
            {
                $ManualPaketEntries = Get-BrownserveContent -Path $PaketDependenciesPath |
                    Select-BrownserveContent -After '## Manually defined dependencies: ##' -FailIfNotFound
            }
            catch
            {
                $UnParsableFiles += $PaketDependenciesPath
            }
        }
        # And for any custom _init.ps1 steps
        if (Test-Path $InitPath)
        {
            Write-Verbose 'Parsing existing _init.ps1 file.'
            try
            {
                $CurrentInitContent = Get-BrownserveContent -Path $InitPath -ErrorAction 'Stop'
                $CustomInitSteps = $CurrentInitContent |
                    Select-BrownserveContent `
                        -After '### Start user defined _init steps' `
                        -Before '### End user defined _init steps' `
                        -FailIfNotFound
            }
            catch
            {
                $UnParsableFiles += $InitPath
            }
        }

        # Build up our default list of gitignore's that we always want to use
        # TODO: Do we want to make ignoring paket.lock optional?
        $DefaultGitIgnores = $GitIgnoreConfig.Defaults

        # Set-up the paket dependency that are common to all our projects
        $DefaultPaketDependencies = $PaketDependenciesConfig.Defaults

        # Careful -AsHashtable makes key names case sensitive when converted from JSON! (defaults != Defaults)
        $DefaultVSCodeExtensions = $VSCodeExtensionsConfig.Defaults

        $DefaultPackageAliases = $PackageAliasConfig.Defaults

        $DefaultEditorConfig = $EditorConfigConfig.Defaults

        # We don't use a config file to create the manifest file as it's a simple object
        $NewManifest = [System.Management.Automation.OrderedHashtable]@{
            RepositoryType  = $ProjectType.ToString()
            ManifestVersion = '1.0.0'
        }

        switch ($ProjectType)
        {
            <#
                For a repo that houses a PowerShell module we'll want to include:
                    - The logic for loading the module as part of the _init script
                    - PlatyPS for building module documentation
                    - powershell-yaml for working with CI/CD files
                    - Invoke-Build/Pester for building and testing the module
            #>
            'PowerShellModule'
            {
                Write-Debug 'PowerShell Module selected'
                # Check our configuration files for any special logic when working with PowerShell module repos
                $DockerfileName = $DevcontainerConfig.PowerShellModule.Dockerfile
                $ExtraPermanentPaths = $RepositoryPathsConfig.PowerShellModule.PermanentPaths
                $ExtraEphemeralPaths = $RepositoryPathsConfig.PowerShellModule.EphemeralPaths
                $ExtraPaketDeps = $PaketDependenciesConfig.PowerShellModule
                $ExtraGitIgnores = $GitIgnoreConfig.PowerShellModule
                $ExtraVSCodeExtensions = $VSCodeExtensionsConfig.PowerShellModule
                $ExtraPackageAliases = $PackageAliasConfig.PowerShellModule
                $ExtraEditorConfig = $EditorConfigConfig.PowerShellModule
                $IncludeChangelog = $true
                $InitParams = @{
                    IncludeModuleLoader   = $true
                    IncludePowerShellYaml = $true
                    IncludePlatyPS        = $true
                    IncludeBuildTestTools = $true
                }
                $LicenseType = 'MIT'
                $IncludeWorkflows = $true
                $IncludeMarkdownlint = $true
                $IncludeDependabot = $true
                $IncludeLabelPR = $true
                $IncludeBuildScripts = $true
                $IncludeHelpTests = $true
                $IncludeMkDocs = $true
                $DependabotParams = @{
                    Updates = @(
                        @{ Ecosystem = 'github-actions'; Directory = '/';       Interval = 'weekly' },
                        @{ Ecosystem = 'nuget';          Directory = '/.config'; Interval = 'weekly' }
                    )
                }
            }
            <#
                For the repo that houses this very PowerShell module we want to do things a little differently.
                We avoid loading the Brownserve.PSTools module locally in _init.ps1 and use nuget as normal to get a stable version
                (this ensures that we can still get notified of failed builds)
                We can use our build to load the local version of the module.
            #>
            'BrownservePSTools'
            {
                Write-Debug 'BrownservePSTools selected'
                # For now we use the same basic config as all our other PowerShell modules except in the params below
                $DockerfileName = $DevcontainerConfig.PowerShellModule.Dockerfile
                $ExtraPermanentPaths = $RepositoryPathsConfig.PowerShellModule.PermanentPaths
                $ExtraEphemeralPaths = $RepositoryPathsConfig.PowerShellModule.EphemeralPaths
                $ExtraPaketDeps = $PaketDependenciesConfig.PowerShellModule
                $ExtraGitIgnores = $GitIgnoreConfig.PowerShellModule
                $ExtraVSCodeExtensions = $VSCodeExtensionsConfig.PowerShellModule
                $ExtraPackageAliases = $PackageAliasConfig.PowerShellModule
                $ExtraEditorConfig = $EditorConfigConfig.PowerShellModule
                $IncludeChangelog = $true
                $InitParams = @{
                    IncludeModuleLoader   = $false # we don't want to load the module locally, we want the stable version from nuget
                    IncludePowerShellYaml = $true
                    IncludePlatyPS        = $true
                    IncludeBuildTestTools = $true
                }
                $IncludeWorkflows = $true
                $IncludeMarkdownlint = $true
                $IncludeDependabot = $true
                $IncludeLabelPR = $true
                $IncludeBuildScripts = $true
                $IncludeHelpTests = $true
                $IncludeMkDocs = $true
                $BuildScriptUseWorkingCopyOption = $true
                $DependabotParams = @{
                    Updates = @(
                        @{ Ecosystem = 'github-actions'; Directory = '/';       Interval = 'weekly' },
                        @{ Ecosystem = 'nuget';          Directory = '/.config'; Interval = 'weekly' }
                    )
                }
            }
            Default
            {
                Write-Debug 'Generic project type selected'
                # We always need the $InitParams hashtable otherwise we'll get a null-valued expression error
                $InitParams = @{
                    IncludeModuleLoader   = $false
                    IncludePowerShellYaml = $false
                    IncludePlatyPS        = $false
                    IncludeBuildTestTools = $false
                }
            }
        }

        if ($IncludeWorkflows -and -not $ModuleInfo)
        {
            throw "A '-ModuleInfo' value is required for '$ProjectType' repositories."
        }

        if ($UnParsableFiles.Count -gt 0 -and !$Force)
        {
            {
                <#
                    Throw here, this allows us to give the user a list of files that need to be manually checked.
                    Then the user can either modify the files themselves or pass -Force to this cmdlet to overwrite them.
                #>
                throw "The following files already exist in the repository but are in a format that can't be parsed:`n$($UnParsableFiles -join "`n")"
            }
        }

        if ($DockerfileName)
        {
            $DevcontainerParams = @{
                Dockerfile         = $DockerfileName
                RequiredExtensions = @()
            }
        }

        if ($ExtraPermanentPaths)
        {
            $FinalPermanentPaths = $DefaultPermanentPaths + $ExtraPermanentPaths
        }
        else
        {
            $FinalPermanentPaths = $DefaultPermanentPaths
        }
        if ($ExtraEphemeralPaths.Count -gt 0)
        {
            $FinalEphemeralPaths = $DefaultEphemeralPaths + $ExtraEphemeralPaths
        }
        else
        {
            $FinalEphemeralPaths = $DefaultEphemeralPaths
        }

        $InitParams.Add('PermanentPaths', $FinalPermanentPaths)
        $InitParams.Add('EphemeralPaths', $FinalEphemeralPaths)

        if ($ExtraGitIgnores)
        {
            $FinalGitIgnores = $DefaultGitIgnores + $ExtraGitIgnores
        }
        else
        {
            $FinalGitIgnores = $DefaultGitIgnores
        }
        if ($ExtraPackageAliases)
        {
            $FinalPackageAliases = $DefaultPackageAliases + $ExtraPackageAliases
        }
        else
        {
            $FinalPackageAliases = $DefaultPackageAliases
        }
        if ($FinalPackageAliases)
        {
            $InitParams.Add('PackageAliases', $FinalPackageAliases)
        }
        $GitIgnoreParams = @{
            GitIgnores = $FinalGitIgnores
        }
        if ($ManualGitIgnores)
        {
            $GitIgnoreParams.Add('ManualGitIgnores', $ManualGitIgnores)
        }

        if ($ExtraPaketDeps)
        {
            $FinalPaketDependencies = $DefaultPaketDependencies + $ExtraPaketDeps
        }
        else
        {
            $FinalPaketDependencies = $DefaultPaketDependencies
        }
        $PaketParams = @{
            PaketDependencies = $FinalPaketDependencies
        }
        if ($ManualPaketEntries)
        {
            $PaketParams.Add('ManualDependencies', $ManualPaketEntries)
        }

        if ($ExtraEditorConfig)
        {
            $FinalEditorConfig = $DefaultEditorConfig + $ExtraEditorConfig
        }
        else
        {
            $FinalEditorConfig = $DefaultEditorConfig
        }
        $EditorConfigParams = @{
            IncludeRoot = $true
            Section     = $FinalEditorConfig
        }

        if ($CustomInitSteps)
        {
            $InitParams.Add('CustomInitSteps', $CustomInitSteps)
        }
        if ($ExtraVSCodeExtensions)
        {
            $VSCodeExtensions = $DefaultVSCodeExtensions + $ExtraVSCodeExtensions
        }
        else
        {
            $VSCodeExtensions = $DefaultVSCodeExtensions
        }
        if ($VSCodeExtensions.Count -gt 0)
        {
            # Extract the list of extension ID's we want to install in this repo and clean up any duplicates
            $VSCodeWorkspaceExtensionIDs += $VSCodeExtensions.ExtensionID
            $VSCodeWorkspaceExtensionIDs = $VSCodeWorkspaceExtensionIDs | Select-Object -Unique

            <#
                Due to the way we store the VS Code settings in our config file, they end up getting read out as an array
                when we expand the object property.
                However the cmdlet that creates the settings file expects a hashtable.
                By far the easiest method to convert this to a hashtable is to pass our array of Hashtable's to the
                Merge-Hashtable cmdlet as the InputObject with a blank hashtable as the BaseObject.
                This results in a hashtable being returned with the correct key/value pairs.
                We specify the -Deep parameter so a deep merge is performed, this ensures that any settings that already
                exist in the repo are preserved.
            #>
            try
            {
                $VSCodeExtensionSettings = Merge-Hashtable `
                    -BaseObject @{} `
                    -InputObject $VSCodeExtensions.CustomSettings `
                    -Deep `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to convert VS Code extension settings to hashtable.`n$($_.Exception.Message)"
            }
            <#
                Check to see if the repository already has any VS Code settings - it affects the order of the hash merge
                Our Merge-Hashtable cmdlet will overwrite the keys of the base object with the input object if there is a clash
                if -Force has been passed then the user is happy to overwrite any settings that already exist in the repo.
                If not we should try and preserve them by using the repo settings as the input object
            #>
            if ($VSCodeWorkspaceSettings.Count -gt 0)
            {
                $MergeParams = @{
                    BaseObject  = $VSCodeWorkspaceSettings
                    InputObject = $VSCodeExtensionSettings
                }
                if (!$Force)
                {
                    $MergeParams = @{
                        BaseObject  = $VSCodeExtensionSettings
                        InputObject = $VSCodeWorkspaceSettings
                    }
                }
                try
                {
                    $VSCodeWorkspaceSettings = Merge-Hashtable `
                        @MergeParams `
                        -Deep `
                        -ErrorAction 'Stop'
                }
                catch
                {
                    throw "Failed to merge repository VS code settings.`n$($_.Exception.Message)"
                }
            }
            else
            {
                $VSCodeWorkspaceSettings = $VSCodeExtensionSettings
            }
            <#
                Once we've merged the settings we like to ensure that they are sorted alphabetically.
                This ensures that the settings file is easier to read and also makes it easier to spot any discrepancies.
            #>
            $VSCodeWorkspaceSettings = ConvertTo-SortedHashtable $VSCodeWorkspaceSettings
        }

        # Create the _init script as that will always be required
        try
        {
            $NewInitScriptContent = New-BrownserveInitScript @InitParams -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to generate _init.ps1 content.`n$($_.Exception.Message)"
        }

        # The .gitignore file should always be required too
        try
        {
            $NewGitIgnoresContent = New-GitIgnoresFile @GitIgnoreParams -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to generate .gitignore file.`n$($_.Exception.Message)"
        }

        # Again the nuget.config file will always be needed
        try
        {
            Invoke-NativeCommand `
                -FilePath 'dotnet' `
                -ArgumentList 'new', 'nugetconfig' `
                -WorkingDirectory $TempDir `
                -SuppressOutput
            $NugetConfigTempPath = Join-Path $TempDir 'nuget.config'
            if (!(Test-Path $NugetConfigTempPath))
            {
                Write-Error 'Cannot find staging nuget.config file.'
            }
        }
        catch
        {
            throw "Failed to generate nuget.config.`n$($_.Exception.Message)"
        }

        # As will the dotnet tools manifest
        try
        {
            <#
                Newer .NET SDK versions create dotnet-tools.json in the working directory root rather than
                in a .config/ subdirectory, so we look at the root of the temp dir for the staging file.
                The destination in the actual repo remains at .config/dotnet-tools.json, which is the
                documented standard location that dotnet tool restore checks.
            #>
            $dotnetToolsTempPath = Join-Path $TempDir 'dotnet-tools.json'
            Invoke-NativeCommand `
                -FilePath 'dotnet' `
                -ArgumentList 'new', 'tool-manifest' `
                -WorkingDirectory $TempDir `
                -SuppressOutput
            Invoke-NativeCommand `
                -FilePath 'dotnet' `
                -ArgumentList 'tool', 'install', 'Paket' `
                -WorkingDirectory $TempDir `
                -SuppressOutput
            if (!(Test-Path $dotnetToolsTempPath))
            {
                Write-Error 'Cannot find staging dotnet tools manifest.'
            }
        }
        catch
        {
            throw "Failed to generate dotnet tools manifest.`n$($_.Exception.Message)"
        }

        # Paket may or may not be required
        if ($PaketParams)
        {
            try
            {
                $NewPaketDependenciesContent = New-PaketDependenciesFile @PaketParams -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to generate paket.dependencies file.`n$($_.Exception.Message)"
            }
        }

        if ($DevcontainerParams)
        {
            $DevcontainerParams.RequiredExtensions = $VSCodeWorkspaceExtensionIDs
            try
            {
                $Devcontainer = New-VSCodeDevContainer @DevcontainerParams -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to create devcontainer.`n$($_.Exception.Message)"
            }
        }

        if ($EditorConfigParams)
        {
            # Try to preserve any manual changes that may have been made to the editorconfig file
            if (Test-Path $EditorConfigPath)
            {
                try
                {
                    $ManualEditorConfig = Read-BrownserveEditorConfig -Path $EditorConfigPath -ErrorAction 'Stop'
                }
                catch
                {
                    # Let this silently fail and just try and create the editorconfig anyways
                    # (If we've got here then -Force has been passed so we should overwrite any existing editorconfig file)
                }
            }
            if ($ManualEditorConfig)
            {
                $EditorConfigParams.Add('ManualSection', $ManualEditorConfig)
            }
            try
            {
                $NewEditorConfigContent = New-BrownserveEditorConfig @EditorConfigParams -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to create .editorconfig file content.`n$($_.Exception.Message)"
            }
        }

        $FinalPermanentPaths.GetEnumerator() | ForEach-Object {
            <#
                All paths should be relative to the repository root.
                The entry may contain child paths, hopefully the user has defined them in the correct order so that the parent
                always gets created first!
            #>
            if ($_.ChildPaths)
            {
                $JoinPathParams = @{
                    Path                = $RepositoryPath
                    ChildPath           = $_.Path
                    AdditionalChildPath = $_.ChildPaths
                }
            }
            else
            {
                $JoinPathParams = @{
                    Path      = $RepositoryPath
                    ChildPath = $_.Path
                }
            }
            $PathToCheck = Join-Path @JoinPathParams
            if (!(Test-Path $PathToCheck))
            {
                $MissingDirectories += [pscustomobject]@{
                    Path = $PathToCheck
                }
            }
        }

        # The type of license we use is dependent on the type of project we're working with
        # though in the future we may want to allow the user to override this.
        if ($LicenseType)
        {
            $NewLicenseContent = New-SPDXLicense `
                -LicenseType $LicenseType `
                -Owner $Owner `
                -ErrorAction 'Stop' | Format-BrownserveContent
        }

        <#
            Now that we've generated all the files for the repository we will compare them
            to any existing files in the repo.
            If the content matches then we don't need to do anything.
            If there's a difference then we'll add the file to the list of changed files.
            If the files don't exist at all then we'll add them to the list of missing files.

            We set the SyncWindow to 1 to try and make the comparison more readable.
            This should ensure that adding a new line to the template file would result in a single addition
            being reported against the DifferenceObject rather than an addition against the
            DifferenceObject and a removal against the ReferenceObject.
            Similarly if a line is removed from the template file we should only see a single removal
            against the ReferenceObject rather than a removal against the ReferenceObject and an addition
            against the DifferenceObject.

            Unfortunately there is no way to detect unexpected changes to any files already in the repo as there's no way to tell
            if the changes are the result of the template changing or if they were made manually.

            But any manual changes should be picked up by the user in the VCS diff.
        #>

        try
        {
            $NewManifestJSON = ConvertTo-Json $NewManifest -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
            $CurrentManifestJSON = ConvertTo-Json $CurrentManifest -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
            if ($CurrentManifest)
            {
                Write-Verbose 'Checking for changes to repository manifest'
                $ManifestCompare = Compare-Object `
                    -ReferenceObject $CurrentManifestJSON.Content `
                    -DifferenceObject $NewManifestJSON.Content `
                    -SyncWindow 1 `
                    -ErrorAction 'Stop'
                if ($ManifestCompare)
                {
                    Write-Verbose 'Changes detected in repository manifest'
                    $ChangedFiles += [pscustomobject]@{
                        Path       = $ManifestPath
                        Content    = $NewManifestJSON.Content
                        LineEnding = 'LF'
                    }
                }
            }
            else
            {
                Write-Verbose 'No existing repository manifest found, will create a new one.'
                $MissingFiles += [pscustomobject]@{
                    Path       = $ManifestPath
                    Content    = $NewManifestJSON.Content
                    LineEnding = 'LF'
                }
            }
        }
        catch
        {
            throw "Failed to process '$ManifestPath'.`n$($_.Exception.Message)"
        }
        try
        {
            $NewNugetConfig = Get-BrownserveContent -Path $NugetConfigTempPath -ErrorAction 'Stop'
            if ((Test-Path $NugetConfigPath))
            {
                Write-Verbose 'Checking for changes to nuget.config'
                $CurrentNugetConfig = Get-BrownserveContent -Path $NugetConfigPath -ErrorAction 'Stop'
                $NugetConfigCompare = Compare-Object `
                    -ReferenceObject $CurrentNugetConfig.Content `
                    -DifferenceObject $NewNugetConfig.Content `
                    -SyncWindow 1 `
                    -ErrorAction 'Stop'
                if ($NugetConfigCompare)
                {
                    Write-Verbose 'Changes detected in nuget.config'
                    $ChangedFiles += [pscustomobject]@{
                        Path       = $NugetConfigPath
                        Content    = $NewNugetConfig.Content
                        LineEnding = 'LF'
                    }
                }
            }
            else
            {
                Write-Verbose 'No existing nuget.config found, will create a new one.'
                $MissingFiles += [pscustomobject]@{
                    Path       = $NugetConfigPath
                    Content    = $NewNugetConfig.Content
                    LineEnding = 'LF'
                }
            }
        }
        catch
        {
            throw "Failed to process '$NugetConfigPath'.`n$($_.Exception.Message)"
        }
        <#
            We don't perform any modifications to the dotnet tools manifest, so we'll just test for it's existence
        #>
        if (!(Test-Path $dotnetToolsConfigPath) -and ($MissingDirectories.Path -notcontains $dotnetToolsConfigPath))
        {
            $MissingDirectories += [pscustomobject]@{
                Path = $dotnetToolsConfigPath
            }
        }
        if (!(Test-Path $dotnetToolsPath))
        {
            try
            {
                $dotnetToolsContent = Get-Content $dotnetToolsTempPath -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to read dotnet-tools.json content.`n$($_.Exception.Message)"
            }
            Write-Verbose 'No existing dotnet-tools.json found, will create a new one.'
            $MissingFiles += [pscustomobject]@{
                Path       = $dotnetToolsPath
                Content    = $dotnetToolsContent
                LineEnding = 'LF'
            }
        }

        if ($CurrentInitContent)
        {
            Write-Verbose 'Checking for changes to _init.ps1'
            $InitCompare = Compare-Object `
                -ReferenceObject $CurrentInitContent.Content `
                -DifferenceObject $NewInitScriptContent.Content `
                -SyncWindow 1 `
                -ErrorAction 'Stop'
            if ($InitCompare)
            {
                Write-Verbose 'Changes detected in _init.ps1'
                $ChangedFiles += [pscustomobject]@{
                    Path       = $InitPath
                    Content    = $NewInitScriptContent.Content
                    LineEnding = 'LF'
                }
            }
        }
        else
        {
            Write-Verbose 'No existing _init.ps1 found, will create a new one.'
            $MissingFiles += [pscustomobject]@{
                Path       = $InitPath
                Content    = $NewInitScriptContent.Content
                LineEnding = 'LF'
            }
        }

        if ($CurrentGitIgnores)
        {
            Write-Verbose 'Checking for changes to .gitignore'
            $GitIgnoreCompare = Compare-Object `
                -ReferenceObject $CurrentGitIgnores.Content `
                -DifferenceObject $NewGitIgnoresContent.Content `
                -SyncWindow 1 `
                -ErrorAction 'Stop'
            if ($GitIgnoreCompare)
            {
                Write-Verbose 'Changes detected in .gitignore'
                $ChangedFiles += [pscustomobject]@{
                    Path       = $GitIgnorePath
                    Content    = $NewGitIgnoresContent.Content
                    LineEnding = 'LF'
                }
            }
        }
        else
        {
            Write-Verbose 'No existing .gitignore found, will create a new one.'
            $MissingFiles += [pscustomobject]@{
                Path       = $GitIgnorePath
                Content    = $NewGitIgnoresContent.Content
                LineEnding = 'LF'
            }
        }

        # Ensure the VS Code directory exists
        if (!(Test-Path $VSCodePath) -and ($MissingDirectories.Path -notcontains $VSCodePath))
        {
            $MissingDirectories += [pscustomobject]@{
                Path = $VSCodePath
            }
        }

        try
        {
            $VSCodeWorkspaceExtensionIDsJSON = ConvertTo-Json `
                -InputObject @{ recommendations = $VSCodeWorkspaceExtensionIDs } `
                -Depth 100 `
                -ErrorAction 'Stop' | Format-BrownserveContent
            if ((Test-Path $VSCodeExtensionsFilePath))
            {
                Write-Verbose 'Checking for changes to VS Code extensions.json'
                $CurrentVSCodeExtensions = Get-BrownserveContent -Path $VSCodeExtensionsFilePath -ErrorAction 'Stop'
                $VSCodeExtensionsCompare = Compare-Object `
                    -ReferenceObject $CurrentVSCodeExtensions.Content `
                    -DifferenceObject $VSCodeWorkspaceExtensionIDsJSON.Content `
                    -SyncWindow 1 `
                    -ErrorAction 'Stop'
                if ($VSCodeExtensionsCompare)
                {
                    Write-Verbose 'Changes detected in VS Code extensions.json'
                    $ChangedFiles += [pscustomobject]@{
                        Path       = $VSCodeExtensionsFilePath
                        Content    = $VSCodeWorkspaceExtensionIDsJSON.Content
                        LineEnding = 'LF'
                    }
                }
            }
            else
            {
                Write-Verbose 'No existing extensions.json found, will create a new one.'
                $MissingFiles += [pscustomobject]@{
                    Path       = $VSCodeExtensionsFilePath
                    Content    = $VSCodeWorkspaceExtensionIDsJSON.Content
                    LineEnding = 'LF'
                }
            }
        }
        catch
        {
            throw "Failed to process '$VSCodeExtensionsFilePath'.`n$($_.Exception.Message)"
        }

        try
        {
            $VSCodeWorkspaceSettingsJSON = ConvertTo-Json `
                -InputObject $VSCodeWorkspaceSettings `
                -Depth 100 `
                -ErrorAction 'Stop' | Format-BrownserveContent
            if ((Test-Path $VSCodeWorkspaceSettingsFilePath))
            {
                Write-Verbose 'Checking for changes to VS Code settings.json'
                $CurrentVSCodeWorkspaceSettings = Get-BrownserveContent -Path $VSCodeWorkspaceSettingsFilePath -ErrorAction 'Stop'
                $VSCodeWorkspaceSettingsCompare = Compare-Object `
                    -ReferenceObject $CurrentVSCodeWorkspaceSettings.Content `
                    -DifferenceObject $VSCodeWorkspaceSettingsJSON.Content `
                    -SyncWindow 1 `
                    -ErrorAction 'Stop'
                if ($VSCodeWorkspaceSettingsCompare)
                {
                    Write-Verbose 'Changes detected in VS Code settings.json'
                    $ChangedFiles += [pscustomobject]@{
                        Path       = $VSCodeWorkspaceSettingsFilePath
                        Content    = $VSCodeWorkspaceSettingsJSON.Content
                        LineEnding = 'LF'
                    }
                }
            }
            else
            {
                Write-Verbose 'No existing settings.json found, will create a new one.'
                $MissingFiles += [pscustomobject]@{
                    Path       = $VSCodeWorkspaceSettingsFilePath
                    Content    = $VSCodeWorkspaceSettingsJSON.Content
                    LineEnding = 'LF'
                }
            }
        }
        catch
        {
            throw "Failed to process '$VSCodeWorkspaceSettingsFilePath'.`n$($_.Exception.Message)"
        }

        if ($NewPaketDependenciesContent)
        {
            try
            {
                if ((Test-Path $PaketDependenciesPath))
                {
                    Write-Verbose 'Checking for changes to paket.dependencies'
                    $CurrentPaketDependencies = Get-BrownserveContent -Path $PaketDependenciesPath -ErrorAction 'Stop'
                    $PaketDependenciesCompare = Compare-Object `
                        -ReferenceObject $CurrentPaketDependencies.Content `
                        -DifferenceObject $NewPaketDependenciesContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($PaketDependenciesCompare)
                    {
                        Write-Verbose 'Changes detected in paket.dependencies'
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $PaketDependenciesPath
                            Content    = $NewPaketDependenciesContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing paket.dependencies found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $PaketDependenciesPath
                        Content    = $NewPaketDependenciesContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$PaketDependenciesPath'.`n$($_.Exception.Message)"
            }
        }

        if ($Devcontainer)
        {
            try
            {
                # Devcontainer can't exist if the parent directory doesn't exist!
                if ((Test-Path $DevcontainerDirectoryPath))
                {
                    if ((Test-Path $DevcontainerPath))
                    {
                        Write-Verbose 'Checking for changes to devcontainer.json'
                        $CurrentDevcontainer = Get-BrownserveContent -Path $DevcontainerPath -ErrorAction 'Stop'
                        $DevcontainerCompare = Compare-Object `
                            -ReferenceObject $CurrentDevcontainer.Content `
                            -DifferenceObject $Devcontainer.Devcontainer.Content `
                            -SyncWindow 1 `
                            -ErrorAction 'Stop'
                        if ($DevcontainerCompare)
                        {
                            Write-Verbose 'Changes detected in devcontainer.json'
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $DevcontainerPath
                                Content    = $Devcontainer.Devcontainer.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose 'No existing devcontainer.json found, will create a new one.'
                        $MissingFiles += [pscustomobject]@{
                            Path       = $DevcontainerPath
                            Content    = $Devcontainer.Devcontainer.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing .devcontainer directory found, will create a new one.'
                    $MissingDirectories += [pscustomobject]@{
                        Path = $DevcontainerDirectoryPath
                    }
                    $MissingFiles += [pscustomobject]@{
                        Path       = $DevcontainerPath
                        Content    = $Devcontainer.Devcontainer.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$DevcontainerDirectoryPath'"
            }

            try
            {
                if ((Test-Path $DockerfilePath))
                {
                    Write-Verbose 'Checking for changes to Dockerfile'
                    $CurrentDockerfile = Get-BrownserveContent -Path $DockerfilePath -ErrorAction 'Stop'
                    $DockerfileCompare = Compare-Object `
                        -ReferenceObject $CurrentDockerfile.Content `
                        -DifferenceObject $Devcontainer.Dockerfile.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($DockerfileCompare)
                    {
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $DockerfilePath
                            Content    = $Devcontainer.Dockerfile.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing Dockerfile found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $DockerfilePath
                        Content    = $Devcontainer.Dockerfile.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$DockerfilePath'.`n$($_.Exception.Message)"
            }
        }

        if ($NewEditorConfigContent)
        {
            try
            {
                if ((Test-Path $EditorConfigPath))
                {
                    try
                    {
                        Write-Verbose 'Checking for changes to .editorconfig'
                        $CurrentEditorConfig = Get-BrownserveContent -Path $EditorConfigPath -ErrorAction 'Stop'
                        $EditorConfigCompare = Compare-Object `
                            -ReferenceObject $CurrentEditorConfig.Content `
                            -DifferenceObject $NewEditorConfigContent.Content `
                            -SyncWindow 1 `
                            -ErrorAction 'Stop'
                        if ($EditorConfigCompare)
                        {
                            Write-Verbose 'Changes detected in .editorconfig'
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $EditorConfigPath
                                Content    = $NewEditorConfigContent.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
                    catch
                    {
                        throw "Failed to process '$EditorConfigPath'.`n$($_.Exception.Message)"
                    }
                }
                else
                {
                    Write-Verbose 'No existing .editorconfig found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $EditorConfigPath
                        Content    = $NewEditorConfigContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$EditorConfigPath'.`n$($_.Exception.Message)"
            }
        }

        <#
            For the changelog we only create it if it doesn't already exist.
            We never overwrite it as it contains manual release notes.
        #>
        if ($IncludeChangelog)
        {
            if (!(Test-Path $ChangelogPath))
            {
                try
                {
                    $NewChangelogContent = New-BrownserveChangelogHeader -ErrorAction 'Stop' | Format-BrownserveContent
                }
                catch
                {
                    throw "Failed to generate CHANGELOG.md content.`n$($_.Exception.Message)"
                }
                Write-Verbose 'No existing CHANGELOG.md found, will create a new one.'
                $MissingFiles += [pscustomobject]@{
                    Path       = $ChangelogPath
                    Content    = $NewChangelogContent.Content
                    LineEnding = 'LF'
                }
            }
        }

        <#
            We don't ever want to overwrite the license file if it already exists, any changes to the license file
            should be made manually for legal reasons.
        #>
        if ($LicenseType)
        {
            if (!(Test-Path $LicensePath))
            {
                $MissingFiles += [pscustomobject]@{
                    Path       = $LicensePath
                    Content    = $NewLicenseContent.Content
                    LineEnding = 'LF'
                }
            }
        }

        <#
            We deliberately overwrite any existing .markdownlint.json.
            We want a consistent gold standard across all our repos rather than per-repo drift,
            so any local customisations will be lost on the next init/update.
        #>
        if ($IncludeMarkdownlint)
        {
            try
            {
                $NewMarkdownlintContent = ConvertTo-Json `
                    -InputObject $MarkdownlintConfig `
                    -Depth 100 `
                    -ErrorAction 'Stop' | Format-BrownserveContent
                if ((Test-Path $MarkdownlintConfigPath))
                {
                    Write-Verbose 'Checking for changes to .markdownlint.json'
                    $CurrentMarkdownlintContent = Get-BrownserveContent -Path $MarkdownlintConfigPath -ErrorAction 'Stop'
                    $MarkdownlintCompare = Compare-Object `
                        -ReferenceObject $CurrentMarkdownlintContent.Content `
                        -DifferenceObject $NewMarkdownlintContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($MarkdownlintCompare)
                    {
                        Write-Verbose 'Changes detected in .markdownlint.json'
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $MarkdownlintConfigPath
                            Content    = $NewMarkdownlintContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing .markdownlint.json found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $MarkdownlintConfigPath
                        Content    = $NewMarkdownlintContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$MarkdownlintConfigPath'.`n$($_.Exception.Message)"
            }
        }

        if ($ModuleInfo)
        {
            $ModuleInfoPath = Join-Path $BuildDirectory 'ModuleInfo.json'
            try
            {
                $ModuleInfoMap = [ordered]@{
                    Name        = $ModuleInfo.Name
                    Description = $ModuleInfo.Description
                    GUID        = $ModuleInfo.GUID
                    Tags        = $ModuleInfo.Tags
                }
                if ($ModuleInfo.RequiredModules)
                {
                    $ModuleInfoMap.RequiredModules = $ModuleInfo.RequiredModules
                }
                $NewModuleInfoContent = $ModuleInfoMap | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
                if (Test-Path $ModuleInfoPath)
                {
                    Write-Verbose 'Checking for changes to ModuleInfo.json'
                    $CurrentModuleInfoContent = Get-BrownserveContent -Path $ModuleInfoPath -ErrorAction 'Stop'
                    $ModuleInfoCompare = Compare-Object `
                        -ReferenceObject $CurrentModuleInfoContent.Content `
                        -DifferenceObject $NewModuleInfoContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($ModuleInfoCompare)
                    {
                        Write-Verbose 'Changes detected in ModuleInfo.json'
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $ModuleInfoPath
                            Content    = $NewModuleInfoContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing ModuleInfo.json found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $ModuleInfoPath
                        Content    = $NewModuleInfoContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$ModuleInfoPath'.`n$($_.Exception.Message)"
            }
        }

        if ($IncludeWorkflows)
        {
            if (-not $RepoName)
            {
                $RepoName = Split-Path $RepositoryPath -Leaf
            }

            $BuildsWorkflowPath = Join-Path $WorkflowDirectory 'builds.yaml'
            $StageReleaseWorkflowPath = Join-Path $WorkflowDirectory 'stage-release.yaml'
            $ReleaseWorkflowPath = Join-Path $WorkflowDirectory 'release.yaml'

            $WorkflowCommonParams = @{ ModuleName = $ModuleInfo.Name; RepoName = $RepoName }

            try
            {
                $NewBuildsWorkflowContent = New-BrownserveGitHubBuildsWorkflow -ModuleName $ModuleInfo.Name -RepoName $RepoName | Format-BrownserveContent
                $NewStageReleaseWorkflowContent = New-BrownserveGitHubStageReleaseWorkflow @WorkflowCommonParams | Format-BrownserveContent
                $NewReleaseWorkflowContent = New-BrownserveGitHubReleaseWorkflow @WorkflowCommonParams | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to generate GitHub Actions workflow content.`n$($_.Exception.Message)"
            }

            if (!(Test-Path $GitHubDirectory) -and ($MissingDirectories.Path -notcontains $GitHubDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $GitHubDirectory }
            }
            if (!(Test-Path $WorkflowDirectory) -and ($MissingDirectories.Path -notcontains $WorkflowDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $WorkflowDirectory }
            }

            $WorkflowFiles = @(
                @{ Path = $BuildsWorkflowPath; Content = $NewBuildsWorkflowContent },
                @{ Path = $StageReleaseWorkflowPath; Content = $NewStageReleaseWorkflowContent },
                @{ Path = $ReleaseWorkflowPath; Content = $NewReleaseWorkflowContent }
            )
            foreach ($WorkflowFile in $WorkflowFiles)
            {
                try
                {
                    if (Test-Path $WorkflowFile.Path)
                    {
                        Write-Verbose "Checking for changes to '$($WorkflowFile.Path)'"
                        $CurrentWorkflowContent = Get-BrownserveContent -Path $WorkflowFile.Path -ErrorAction 'Stop'
                        $WorkflowCompare = Compare-Object `
                            -ReferenceObject $CurrentWorkflowContent.Content `
                            -DifferenceObject $WorkflowFile.Content.Content `
                            -SyncWindow 1 `
                            -ErrorAction 'Stop'
                        if ($WorkflowCompare)
                        {
                            Write-Verbose "Changes detected in '$($WorkflowFile.Path)'"
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $WorkflowFile.Path
                                Content    = $WorkflowFile.Content.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "No existing workflow file found at '$($WorkflowFile.Path)', will create a new one."
                        $MissingFiles += [pscustomobject]@{
                            Path       = $WorkflowFile.Path
                            Content    = $WorkflowFile.Content.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                catch
                {
                    throw "Failed to process '$($WorkflowFile.Path)'.`n$($_.Exception.Message)"
                }
            }
        }

        if ($IncludeLabelPR)
        {
            $LabelPRWorkflowPath = Join-Path $WorkflowDirectory 'label-pr.yaml'

            if (!(Test-Path $GitHubDirectory) -and ($MissingDirectories.Path -notcontains $GitHubDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $GitHubDirectory }
            }
            if (!(Test-Path $WorkflowDirectory) -and ($MissingDirectories.Path -notcontains $WorkflowDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $WorkflowDirectory }
            }

            try
            {
                $NewLabelPRWorkflowContent = New-BrownserveGitHubLabelPRWorkflow | Format-BrownserveContent
                if (Test-Path $LabelPRWorkflowPath)
                {
                    Write-Verbose "Checking for changes to '$LabelPRWorkflowPath'"
                    $CurrentLabelPRWorkflowContent = Get-BrownserveContent -Path $LabelPRWorkflowPath -ErrorAction 'Stop'
                    $LabelPRCompare = Compare-Object `
                        -ReferenceObject $CurrentLabelPRWorkflowContent.Content `
                        -DifferenceObject $NewLabelPRWorkflowContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($LabelPRCompare)
                    {
                        Write-Verbose "Changes detected in '$LabelPRWorkflowPath'"
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $LabelPRWorkflowPath
                            Content    = $NewLabelPRWorkflowContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose "No existing label-pr.yaml found, will create a new one."
                    $MissingFiles += [pscustomobject]@{
                        Path       = $LabelPRWorkflowPath
                        Content    = $NewLabelPRWorkflowContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$LabelPRWorkflowPath'.`n$($_.Exception.Message)"
            }
        }

        if ($IncludeBuildScripts)
        {
            $BuildScriptPath = Join-Path $BuildDirectory 'build.ps1'
            $BuildTasksScriptPath = Join-Path $BuildTasksDirectory 'build_tasks.ps1'

            $BuildScriptParams = @{}
            if ($BuildScriptUseWorkingCopyOption)
            {
                $BuildScriptParams['IncludeUseWorkingCopyOption'] = $true
            }

            try
            {
                $NewBuildScriptContent = New-BrownserveBuildScript @BuildScriptParams | Format-BrownserveContent
                $NewBuildTasksScriptContent = New-BrownserveBuildTasksScript @BuildScriptParams | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to generate build script content.`n$($_.Exception.Message)"
            }

            if (!(Test-Path $BuildDirectory) -and ($MissingDirectories.Path -notcontains $BuildDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $BuildDirectory }
            }
            if (!(Test-Path $BuildTasksDirectory) -and ($MissingDirectories.Path -notcontains $BuildTasksDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $BuildTasksDirectory }
            }

            $BuildFiles = @(
                @{ Path = $BuildScriptPath; Content = $NewBuildScriptContent },
                @{ Path = $BuildTasksScriptPath; Content = $NewBuildTasksScriptContent }
            )
            foreach ($BuildFile in $BuildFiles)
            {
                try
                {
                    if (Test-Path $BuildFile.Path)
                    {
                        Write-Verbose "Checking for changes to '$($BuildFile.Path)'"
                        $CurrentBuildFileContent = Get-BrownserveContent -Path $BuildFile.Path -ErrorAction 'Stop'
                        $BuildFileCompare = Compare-Object `
                            -ReferenceObject $CurrentBuildFileContent.Content `
                            -DifferenceObject $BuildFile.Content.Content `
                            -SyncWindow 1 `
                            -ErrorAction 'Stop'
                        if ($BuildFileCompare)
                        {
                            Write-Verbose "Changes detected in '$($BuildFile.Path)'"
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $BuildFile.Path
                                Content    = $BuildFile.Content.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "No existing build file found at '$($BuildFile.Path)', will create a new one."
                        $MissingFiles += [pscustomobject]@{
                            Path       = $BuildFile.Path
                            Content    = $BuildFile.Content.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                catch
                {
                    throw "Failed to process '$($BuildFile.Path)'.`n$($_.Exception.Message)"
                }
            }
        }

        if ($IncludeHelpTests)
        {
            $BuildTestsDirectory = Join-Path $BuildDirectory 'tests'
            $HelpTestsPath = Join-Path $BuildTestsDirectory 'Help.Tests.ps1'

            try
            {
                $NewHelpTestsContent = New-BrownserveHelpTestsScript -ModuleName $ModuleInfo.Name | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to generate Help.Tests.ps1 content.`n$($_.Exception.Message)"
            }

            if (!(Test-Path $BuildTestsDirectory) -and ($MissingDirectories.Path -notcontains $BuildTestsDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $BuildTestsDirectory }
            }

            try
            {
                if (Test-Path $HelpTestsPath)
                {
                    Write-Verbose "Checking for changes to '$HelpTestsPath'"
                    $CurrentHelpTestsContent = Get-BrownserveContent -Path $HelpTestsPath -ErrorAction 'Stop'
                    $HelpTestsCompare = Compare-Object `
                        -ReferenceObject $CurrentHelpTestsContent.Content `
                        -DifferenceObject $NewHelpTestsContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($HelpTestsCompare)
                    {
                        Write-Verbose "Changes detected in '$HelpTestsPath'"
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $HelpTestsPath
                            Content    = $NewHelpTestsContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose "No existing Help.Tests.ps1 found, will create a new one."
                    $MissingFiles += [pscustomobject]@{
                        Path       = $HelpTestsPath
                        Content    = $NewHelpTestsContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$HelpTestsPath'.`n$($_.Exception.Message)"
            }
        }

        if ($IncludeMkDocs)
        {
            $PagesDirectory          = Join-Path $RepositoryPath 'pages'
            $PagesReferenceDirectory = Join-Path $PagesDirectory 'Cmdlet reference'

            foreach ($Dir in @($PagesDirectory, $PagesReferenceDirectory))
            {
                if (!(Test-Path $Dir) -and ($MissingDirectories.Path -notcontains $Dir))
                {
                    $MissingDirectories += [pscustomobject]@{ Path = $Dir }
                }
            }

            try
            {
                $NewMkDocsConfigContent      = New-MkDocsConfig      -ModuleName $ModuleInfo.Name | Format-BrownserveContent
                $NewMkDocsRequirementsContent = New-MkDocsRequirements                             | Format-BrownserveContent
                $NewMkDocsIndexContent       = New-MkDocsIndexPage   -ModuleName $ModuleInfo.Name | Format-BrownserveContent
                $NewMkDocsPagesContent       = New-MkDocsPagesFile                                 | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to generate MkDocs file content.`n$($_.Exception.Message)"
            }

            $MkDocsFiles = @(
                @{ Path = (Join-Path $RepositoryPath 'mkdocs.yml');                          Content = $NewMkDocsConfigContent },
                @{ Path = (Join-Path $RepositoryPath 'requirements.txt');                    Content = $NewMkDocsRequirementsContent },
                @{ Path = (Join-Path $PagesDirectory 'index.md');                            Content = $NewMkDocsIndexContent },
                @{ Path = (Join-Path $PagesReferenceDirectory '.pages');                     Content = $NewMkDocsPagesContent }
            )

            foreach ($MkDocsFile in $MkDocsFiles)
            {
                try
                {
                    if (Test-Path $MkDocsFile.Path)
                    {
                        Write-Verbose "Checking for changes to '$($MkDocsFile.Path)'"
                        $CurrentMkDocsContent = Get-BrownserveContent -Path $MkDocsFile.Path -ErrorAction 'Stop'
                        $MkDocsCompare = Compare-Object `
                            -ReferenceObject $CurrentMkDocsContent.Content `
                            -DifferenceObject $MkDocsFile.Content.Content `
                            -SyncWindow 1 `
                            -ErrorAction 'Stop'
                        if ($MkDocsCompare)
                        {
                            Write-Verbose "Changes detected in '$($MkDocsFile.Path)'"
                            $ChangedFiles += [pscustomobject]@{
                                Path       = $MkDocsFile.Path
                                Content    = $MkDocsFile.Content.Content
                                LineEnding = 'LF'
                            }
                        }
                    }
                    else
                    {
                        Write-Verbose "No existing file found at '$($MkDocsFile.Path)', will create a new one."
                        $MissingFiles += [pscustomobject]@{
                            Path       = $MkDocsFile.Path
                            Content    = $MkDocsFile.Content.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                catch
                {
                    throw "Failed to process '$($MkDocsFile.Path)'.`n$($_.Exception.Message)"
                }
            }
        }
    }
    end
    {
        # Return an object that contains all the information we've gathered
        if ($IncludeDependabot)
        {
            $DependabotGitHubDirectory = Join-Path $RepositoryPath '.github'
            $DependabotPath = Join-Path $DependabotGitHubDirectory 'dependabot.yml'

            # Ensure .github exists; guard against duplicates when $IncludeWorkflows has already added it
            if (!(Test-Path $DependabotGitHubDirectory) -and ($MissingDirectories.Path -notcontains $DependabotGitHubDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $DependabotGitHubDirectory }
            }

            try
            {
                $NewDependabotContent = New-BrownserveDependabotConfig @DependabotParams |
                    Format-BrownserveContent
                if (Test-Path $DependabotPath)
                {
                    Write-Verbose 'Checking for changes to dependabot.yml'
                    $CurrentDependabotContent = Get-BrownserveContent -Path $DependabotPath -ErrorAction 'Stop'
                    $DependabotCompare = Compare-Object `
                        -ReferenceObject $CurrentDependabotContent.Content `
                        -DifferenceObject $NewDependabotContent.Content `
                        -SyncWindow 1 `
                        -ErrorAction 'Stop'
                    if ($DependabotCompare)
                    {
                        Write-Verbose 'Changes detected in dependabot.yml'
                        $ChangedFiles += [pscustomobject]@{
                            Path       = $DependabotPath
                            Content    = $NewDependabotContent.Content
                            LineEnding = 'LF'
                        }
                    }
                }
                else
                {
                    Write-Verbose 'No existing dependabot.yml found, will create a new one.'
                    $MissingFiles += [pscustomobject]@{
                        Path       = $DependabotPath
                        Content    = $NewDependabotContent.Content
                        LineEnding = 'LF'
                    }
                }
            }
            catch
            {
                throw "Failed to process '$DependabotPath'.`n$($_.Exception.Message)"
            }
        }

        $Return = [pscustomobject]@{
            MissingFiles       = $MissingFiles
            ChangedFiles       = $ChangedFiles
            MissingDirectories = $MissingDirectories
        }
        Return $Return
    }
}

