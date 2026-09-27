<#
.SYNOPSIS
    Checks the current state of a repository to see if it is initialised correctly.
.DESCRIPTION
    This cmdlet is pretty complex as we use it to test the state of a given repository on disk to see if it is
    correctly initialised depending on the components the repository has been configured with.
    We don't want to modify any files on disk until we're sure we won't destroy any manual changes that may have
    been made.
    As such this cmdlet will compare the state of the files in the repository to a set of templates that we
    generate based on the resolved components, if the repository is missing any files or if
    the files are different to that of the templates then we'll add them to a list of files that need to be
    created or updated and return them to the calling process to be handled.
    Due to the complexities of comparing files with line endings and formatting we make heavy use of the various
    "*-BrownserveContent" cmdlets to ensure that we can accurately compare the files.
    The actual comparison of each generated file against disk and against the previous manifest is delegated to
    'Compare-BrownserveManagedFile', which is the single place that decides whether a file is missing, changed,
    conflicted or safe to remove. This cmdlet's job is only to generate the content for every file the requested
    components produce and hand the resulting '[BrownserveManagedFile]' list to that function.
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
        $Owner = 'Brownserve-UK',

        # The components that should be present in this repository, 'Core' is always included automatically
        [Parameter(Mandatory = $false)]
        [string[]]
        $Components = @(),

        # Options for the requested components, keyed by component name
        [Parameter(Mandatory = $false)]
        [hashtable]
        $ComponentOptions = @{},

        # The GitHub repository name, if different from the local directory name.
        # Defaults to the leaf name of RepositoryPath if not provided.
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName,

        # Forces the recreation of files even if they already exist
        [Parameter(Mandatory = $false)]
        [switch]
        $Force
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

        try
        {
            $ComponentDefinitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
            $ResolvedComponents = Resolve-BrownserveRepoComponent -Name $Components -Options $ComponentOptions -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to resolve repository components.`n$($_.Exception.Message)"
        }

        try
        {
            $LegacyProfilesPath = Join-Path $Script:BrownserveRepoComponentsDirectory 'LegacyProfiles.psd1'
            $LegacyProfiles = Import-PowerShellDataFile -Path $LegacyProfilesPath -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to read legacy profile data.`n$($_.Exception.Message)"
        }

        try
        {
            $BrownserveModuleVersions = @{
                'Brownserve.PSCommon'        = Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSCommon' -ErrorAction 'Stop'
                'Brownserve.PSSourceControl' = Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSSourceControl' -ErrorAction 'Stop'
                'Brownserve.PSBuildTools'    = Get-BrownserveLoadedModuleVersion -Name 'Brownserve.PSBuildTools' -ErrorAction 'Stop'
            }
        }
        catch
        {
            throw "Failed to resolve the loaded version of a Brownserve module.`n$($_.Exception.Message)"
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
        $MissingDirectories = @()

        $ManagedFiles = [System.Collections.Generic.List[BrownserveManagedFile]]::new()

        <#
            We type constrain these variables to ensure that we can easily add to them later on.
            In the past certain operations had a tendency to return a single string rather than an array of strings
            Which would cause issues when we converted them to JSON.
        #>
        [array]$VSCodeWorkspaceExtensionIDs = @()
        $VSCodeWorkspaceSettings = [ordered]@{}

        $ResolvedByName = @{}
        $ResolvedComponents | ForEach-Object { $ResolvedByName[$_.Name] = $_ }

        <#
            The below paths will always be required regardless of the components we're working with.
        #>
        $DefaultPermanentPathsLookup = $ComponentDefinitions['Core'].Data.PermanentPaths
        $BuildDirectory = Join-Path $RepositoryPath ($DefaultPermanentPathsLookup | Where-Object { $_.VariableName -eq 'BrownserveRepoBuildDirectory' }).Path

        $ManifestPath = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        $InitPath = Join-Path $BuildDirectory '_init.ps1'
        $PaketDependenciesPath = Join-Path $RepositoryPath 'paket.dependencies'
        $dotnetToolsConfigPath = Join-Path $RepositoryPath '.config'
        $dotnetToolsPath = Join-Path $dotnetToolsConfigPath 'dotnet-tools.json'
        $NugetConfigPath = Join-Path $RepositoryPath 'nuget.config'
        $GitIgnorePath = Join-Path $RepositoryPath '.gitignore'

        # These paths may or may not be required depending on the components we're working with
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
            To help with consistency we store a special manifest file in the repository that contains some basic
            information about the repository, including which components it's configured with.
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
        }
        $CurrentManifestFiles = @{}
        if ($CurrentManifest -and $CurrentManifest.Files)
        {
            $CurrentManifestFiles = $CurrentManifest.Files
        }

        function Test-BrownserveRecordedAsMerged([string]$RelativePath)
        {
            $CurrentManifestFiles.ContainsKey($RelativePath) -and $CurrentManifestFiles[$RelativePath].Ownership -eq 'Merged'
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
        catch [System.IO.FileNotFoundException]
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
        catch [System.IO.FileNotFoundException]
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
        $GitIgnoreRelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $GitIgnorePath) -replace '\\', '/'
        $PaketDependenciesRelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $PaketDependenciesPath) -replace '\\', '/'
        $InitRelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $InitPath) -replace '\\', '/'

        if (Test-Path $GitIgnorePath)
        {
            Write-Verbose 'Parsing existing .gitignore file.'
            try
            {
                $CurrentGitIgnores = Get-BrownserveContent -Path $GitIgnorePath -ErrorAction 'Stop'
                $ManualGitIgnores = $CurrentGitIgnores |
                    Select-BrownserveContent -After '## Manually defined ignores: ##' -FailIfNotFound
                $DiskGeneratedGitIgnores = (Split-BrownserveContentAtMarker -Content $CurrentGitIgnores.Content -Marker '## Manually defined ignores: ##' -ErrorAction 'Stop').Before
            }
            catch
            {
                if (Test-BrownserveRecordedAsMerged $GitIgnoreRelativePath)
                {
                    throw "The generated section of '$GitIgnorePath' is damaged and can't be parsed.`n$($_.Exception.Message)"
                }
                $UnParsableFiles += $GitIgnorePath
            }
        }
        # Similarly for paket packages
        if (Test-Path $PaketDependenciesPath)
        {
            Write-Verbose 'Parsing existing paket.dependencies file.'
            try
            {
                $CurrentPaketContent = Get-BrownserveContent -Path $PaketDependenciesPath -ErrorAction 'Stop'
                $ManualPaketEntries = $CurrentPaketContent |
                    Select-BrownserveContent -After '## Manually defined dependencies: ##' -FailIfNotFound
                $DiskGeneratedPaket = (Split-BrownserveContentAtMarker -Content $CurrentPaketContent.Content -Marker '## Manually defined dependencies: ##' -ErrorAction 'Stop').Before
            }
            catch
            {
                if (Test-BrownserveRecordedAsMerged $PaketDependenciesRelativePath)
                {
                    throw "The generated section of '$PaketDependenciesPath' is damaged and can't be parsed.`n$($_.Exception.Message)"
                }
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
                $DiskGeneratedInitBefore = (Split-BrownserveContentAtMarker -Content $CurrentInitContent.Content -Marker '### Start user defined _init steps' -ErrorAction 'Stop').Before
                $DiskGeneratedInitAfter = (Split-BrownserveContentAtMarker -Content $CurrentInitContent.Content -Marker '### End user defined _init steps' -ErrorAction 'Stop').After
                $DiskGeneratedInit = @($DiskGeneratedInitBefore) + @($DiskGeneratedInitAfter)
            }
            catch
            {
                if (Test-BrownserveRecordedAsMerged $InitRelativePath)
                {
                    throw "The generated section of '$InitPath' is damaged and can't be parsed.`n$($_.Exception.Message)"
                }
                $UnParsableFiles += $InitPath
            }
        }

        $GitIgnoreBlocks = @()
        $CorePaketDependencyBlocks = @()
        $ComponentPaketDependencyBlocks = @()
        $PermanentPathEntries = @()
        $EphemeralPathEntries = @()
        $CoreVSCodeExtensions = @()
        $ComponentVSCodeExtensions = @()
        $PackageAliasEntries = @()
        $EditorConfigEntries = @()
        $DependabotExtraUpdates = @()
        $DockerfileName = $null
        $ModuleInfo = $null
        $ReleaseLifecycleData = $null

        $InitParams = @{
            IncludeModuleLoader   = $false
            IncludePowerShellYaml = $false
            IncludePlatyPS        = $false
            IncludeBuildTestTools = $false
        }
        $IncludeChangelog = $false
        $LicenseType = $null
        $IncludeMarkdownlint = $false
        $IncludeLabelPR = $false
        $IncludeContributing = $false
        $IncludePRTemplate = $false
        $IncludeWorkflows = $false
        $IncludeBuildScripts = $false
        $IncludePesterTests = $false
        $IncludeDependabot = $false
        $IncludeMkDocs = $false
        $IncludeAstroDocs = $false
        $IncludeInstallScripts = $false
        $BuildScriptUseWorkingCopyOption = $false
        $DisableGitHubActionsCooldown = $false
        $PowerShellModuleIncludeLicense = $true

        foreach ($Component in $ResolvedComponents)
        {
            $Data = $ComponentDefinitions[$Component.Name].Data
            switch ($Component.Name)
            {
                'Core'
                {
                    $GitIgnoreBlocks += $Data.GitIgnores
                    $CorePaketDependencyBlocks += $Data.PaketDependencies
                    $PermanentPathEntries += $Data.PermanentPaths
                    $EphemeralPathEntries += $Data.EphemeralPaths
                    $CoreVSCodeExtensions += $Data.VSCodeExtensions
                    $PackageAliasEntries += $Data.PackageAliases
                    $EditorConfigEntries += $Data.EditorConfig
                }
                'ReleaseLifecycle'
                {
                    $ReleaseLifecycleData = $Data
                    $EditorConfigEntries += $Data.EditorConfig
                    $IncludeChangelog = $Data.IncludeChangelog
                    $LicenseType = $Data.LicenseType
                    $IncludeMarkdownlint = $Data.IncludeMarkdownlint
                    $IncludeLabelPR = $Data.IncludeLabelPR
                    $IncludeContributing = $Data.IncludeContributing
                    $IncludePRTemplate = $Data.IncludePRTemplate
                    $IncludeWorkflows = $Data.IncludeWorkflows
                    $IncludeBuildScripts = $Data.IncludeBuildScripts
                    $IncludePesterTests = $Data.IncludePesterTests
                    $IncludeDependabot = $Data.IncludeDependabot
                    $InitParams.IncludeBuildTestTools = $true
                }
                'PowerShellModule'
                {
                    $ModuleInfo = $Component.Options.ModuleInfo
                    $PermanentPathEntries += $Data.PermanentPaths
                    $ComponentPaketDependencyBlocks += $Data.PaketDependencies
                    $ComponentVSCodeExtensions += $Data.VSCodeExtensions
                    $PackageAliasEntries += $Data.PackageAliases
                    if (-not $DockerfileName)
                    {
                        $DockerfileName = $Data.Devcontainer.Dockerfile
                    }
                    $DependabotExtraUpdates += $Data.DependabotExtraUpdates
                    $InitParams.IncludePowerShellYaml = $true
                    $InitParams.IncludePlatyPS = $true
                    $InitParams.IncludeModuleLoader = -not [bool]$Component.Options.UseWorkingCopy
                    $BuildScriptUseWorkingCopyOption = [bool]$Component.Options.UseWorkingCopy
                    $DisableGitHubActionsCooldown = [bool]$Component.Options.DisableGitHubActionsCooldown
                    $PowerShellModuleIncludeLicense = [bool]$Component.Options.IncludeLicense
                }
                'RustBinary'
                {
                    $PermanentPathEntries += $Data.PermanentPaths
                    $ComponentPaketDependencyBlocks += $Data.PaketDependencies
                    $GitIgnoreBlocks += $Data.GitIgnores
                    $ComponentVSCodeExtensions += $Data.VSCodeExtensions
                    $EditorConfigEntries += $Data.EditorConfig
                    if (-not $DockerfileName)
                    {
                        $DockerfileName = $Data.Devcontainer.Dockerfile
                    }
                    $DependabotExtraUpdates += $Data.DependabotExtraUpdates
                    $IncludeInstallScripts = [bool]$Data.IncludeInstallScripts
                }
                'ContainerImage'
                {
                    $PermanentPathEntries += $Data.PermanentPaths
                    $ComponentPaketDependencyBlocks += $Data.PaketDependencies
                    if ($Component.Options.IncludeEnvIgnore)
                    {
                        $GitIgnoreBlocks += $Data.EnvGitIgnore
                    }
                    $GitIgnoreBlocks += $Data.GitIgnores
                    $ComponentVSCodeExtensions += $Data.VSCodeExtensions
                    if ($Component.Options.IncludeShellEditorConfig)
                    {
                        $EditorConfigEntries += $Data.ShellEditorConfig
                    }
                    if (-not $DockerfileName)
                    {
                        $DockerfileName = $Data.Devcontainer.Dockerfile
                    }
                    $ContainerDependabotDirectory = if ($Component.Options.Context -eq '.') { '/' } else { "/$($Component.Options.Context)" }
                    $DependabotExtraUpdates += @{ Ecosystem = 'docker'; Directory = $ContainerDependabotDirectory; Interval = 'weekly'; CooldownDays = 30 }
                }
                'DirectoryArchive'
                {
                    $PermanentPathEntries += $Data.PermanentPaths
                    $ComponentPaketDependencyBlocks += $Data.PaketDependencies
                    $GitIgnoreBlocks += $Data.GitIgnores
                    $ComponentVSCodeExtensions += $Data.VSCodeExtensions
                    $EditorConfigEntries += $Data.EditorConfig
                    $SkillsPath = @{} + $Data.PermanentPathTemplate
                    $SkillsPath.Path = $Component.Options.Path
                    $PermanentPathEntries += $SkillsPath
                }
                'MkDocs'
                {
                    $IncludeMkDocs = $true
                }
                'AstroDocs'
                {
                    $IncludeAstroDocs = $true
                    $PermanentPathEntries += $Data.PermanentPaths
                    $DependabotExtraUpdates += $Data.DependabotExtraUpdates
                }
            }
        }

        $SeenPathVariables = @{}
        $FinalPermanentPaths = @()
        foreach ($PathEntry in $PermanentPathEntries)
        {
            if (!$SeenPathVariables.ContainsKey($PathEntry.VariableName))
            {
                $SeenPathVariables[$PathEntry.VariableName] = $true
                $FinalPermanentPaths += $PathEntry
            }
        }
        $FinalEphemeralPaths = $EphemeralPathEntries

        $InitParams.Add('PermanentPaths', $FinalPermanentPaths)
        $InitParams.Add('EphemeralPaths', $FinalEphemeralPaths)

        $FinalPackageAliases = $PackageAliasEntries
        if ($FinalPackageAliases.Count -gt 0)
        {
            $InitParams.Add('PackageAliases', $FinalPackageAliases)
        }

        $FinalGitIgnores = $GitIgnoreBlocks
        $GitIgnoreParams = @{
            GitIgnores = $FinalGitIgnores
        }
        if ($ManualGitIgnores)
        {
            $GitIgnoreParams.Add('ManualGitIgnores', $ManualGitIgnores)
        }

        $CorePaketDependencyBlocks | ForEach-Object {
            $_.Rule | ForEach-Object {
                if ($BrownserveModuleVersions.ContainsKey($_.PackageName))
                {
                    $_['Version'] = $BrownserveModuleVersions[$_.PackageName]
                }
            }
        }
        $SeenPaketPackageNames = @{}
        $FinalPaketDependencies = @()
        foreach ($Block in ($CorePaketDependencyBlocks + $ComponentPaketDependencyBlocks))
        {
            $UnseenRules = @($Block.Rule | Where-Object { !$SeenPaketPackageNames.ContainsKey($_.PackageName) })
            if ($UnseenRules.Count -eq 0)
            {
                continue
            }
            $Block.Rule | ForEach-Object { $SeenPaketPackageNames[$_.PackageName] = $true }
            $FinalPaketDependencies += $Block
        }
        $PaketParams = @{
            PaketDependencies = $FinalPaketDependencies
        }
        if ($ManualPaketEntries)
        {
            $PaketParams.Add('ManualDependencies', $ManualPaketEntries)
        }

        $FinalEditorConfig = $EditorConfigEntries
        $EditorConfigParams = @{
            IncludeRoot = $true
            Section     = $FinalEditorConfig
        }

        if ($CustomInitSteps)
        {
            $InitParams.Add('CustomInitSteps', $CustomInitSteps)
        }

        $VSCodeExtensions = $CoreVSCodeExtensions + $ComponentVSCodeExtensions

        if ($IncludeDependabot)
        {
            $BaseCooldownDays = $ReleaseLifecycleData.DependabotBaseCooldownDays
            if ($DisableGitHubActionsCooldown)
            {
                $BaseCooldownDays = $null
            }
            $DependabotUpdatesFinal = @()
            $BaseUpdate = @{} + $ReleaseLifecycleData.DependabotBaseUpdate
            if ($BaseCooldownDays)
            {
                $BaseUpdate['Cooldown'] = @{ DefaultDays = $BaseCooldownDays }
            }
            $DependabotUpdatesFinal += $BaseUpdate
            foreach ($ExtraUpdate in $DependabotExtraUpdates)
            {
                $Update = @{ Ecosystem = $ExtraUpdate.Ecosystem; Directory = $ExtraUpdate.Directory; Interval = $ExtraUpdate.Interval }
                if ($ExtraUpdate.CooldownDays)
                {
                    $Update['Cooldown'] = @{ DefaultDays = $ExtraUpdate.CooldownDays }
                }
                $DependabotUpdatesFinal += $Update
            }
            $DependabotParams = @{
                Updates = $DependabotUpdatesFinal
            }
        }

        $MarkdownlintConfig = [ordered]@{}
        foreach ($Rule in $ReleaseLifecycleData.MarkdownlintRules)
        {
            $MarkdownlintConfig[$Rule.Name] = $Rule.Value
        }

        if ($ResolvedByName.ContainsKey('PowerShellModule') -and !$PowerShellModuleIncludeLicense)
        {
            $LicenseType = $null
        }

        $TemplatesDirectory = Join-Path $PSScriptRoot 'templates'
        if ($IncludeWorkflows -or $IncludeBuildScripts -or $IncludeContributing -or $IncludePRTemplate -or $IncludePesterTests)
        {
            $ProfileComponentNames = @($ResolvedComponents.Name | Where-Object { $_ -in @('PowerShellModule', 'RustBinary', 'ContainerImage', 'DirectoryArchive') } | Sort-Object)
            $ProfileKey = $ProfileComponentNames -join '+'
            if (!$LegacyProfiles.ContainsKey($ProfileKey))
            {
                throw "The component combination '$ProfileKey' is not supported yet."
            }
            $LegacyProfile = $LegacyProfiles[$ProfileKey]

            if ($LegacyProfile.VSCodeExtensionsOverride)
            {
                $VSCodeExtensions = $CoreVSCodeExtensions + $LegacyProfile.VSCodeExtensionsOverride
            }

            if ($IncludeContributing)
            {
                $ContributingParams = @{
                    TemplateDirectory = $TemplatesDirectory
                    TemplateName      = $LegacyProfile.ContributingTemplate
                }
            }
            if ($IncludePRTemplate)
            {
                $PRTemplateSubstitutions = @{}
                foreach ($Key in $LegacyProfile.PRTemplateSubstitutionKeys)
                {
                    switch ($Key)
                    {
                        'MODULE_NAME' { $PRTemplateSubstitutions['MODULE_NAME'] = $ModuleInfo.Name }
                        'OWNER' { $PRTemplateSubstitutions['OWNER'] = '' }
                        default { $PRTemplateSubstitutions[$Key] = '' }
                    }
                }
                $PRTemplateParams = @{
                    TemplateDirectory = $TemplatesDirectory
                    TemplateName      = $LegacyProfile.PRTemplateTemplate
                    Substitutions     = $PRTemplateSubstitutions
                }
            }
            if ($IncludeWorkflows -and $LegacyProfile.WorkflowTemplates)
            {
                $WorkflowTemplateParams = @{
                    Builds       = @{
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $LegacyProfile.WorkflowTemplates.Builds
                        Substitutions     = @{ REPO_NAME = '' }
                    }
                    StageRelease = @{
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $LegacyProfile.WorkflowTemplates.StageRelease
                        Substitutions     = @{ REPO_NAME = '' }
                    }
                    Release      = @{
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $LegacyProfile.WorkflowTemplates.Release
                        Substitutions     = @{ REPO_NAME = '' }
                    }
                }
            }
            if ($IncludeBuildScripts -and $LegacyProfile.BuildScriptTemplates)
            {
                $BuildScriptTemplateParams = @{
                    BuildScript = @{
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $LegacyProfile.BuildScriptTemplates.BuildScript
                        Substitutions     = @{ REPO_NAME = ''; OWNER = '' }
                    }
                    BuildTasks  = @{
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $LegacyProfile.BuildScriptTemplates.BuildTasks
                        Substitutions     = @{ REPO_NAME = '' }
                    }
                }
            }
            if ($IncludePesterTests)
            {
                $PesterTestsParams = @()
                foreach ($TestSpec in $LegacyProfile.PesterTests)
                {
                    $Substitutions = @{}
                    foreach ($Key in $TestSpec.SubstitutionKeys)
                    {
                        switch ($Key)
                        {
                            'MODULE_NAME' { $Substitutions['MODULE_NAME'] = $ModuleInfo.Name }
                            default { $Substitutions[$Key] = '' }
                        }
                    }
                    $PesterTestsParams += @{
                        FileName          = $TestSpec.FileName
                        TemplateDirectory = $TemplatesDirectory
                        TemplateName      = $TestSpec.TemplateName
                        Substitutions     = $Substitutions
                    }
                }
            }
        }

        if ($DockerfileName)
        {
            $DevcontainerParams = @{
                Dockerfile         = $DockerfileName
                RequiredExtensions = @()
            }
        }

        $VSCodeExtensionsRelativePath = '.vscode/extensions.json'
        $VSCodeSettingsRelativePath = '.vscode/settings.json'
        $DiskVSCodeExtensionIDs = @($VSCodeWorkspaceExtensionIDs)
        $DiskVSCodeSettings = @{}
        if ($VSCodeWorkspaceSettings.Count -gt 0)
        {
            $DiskVSCodeSettings = $VSCodeWorkspaceSettings
        }
        $ExtensionsBaseline = @()
        if ($CurrentManifestFiles.ContainsKey($VSCodeExtensionsRelativePath) -and $CurrentManifestFiles[$VSCodeExtensionsRelativePath].Baseline -and $CurrentManifestFiles[$VSCodeExtensionsRelativePath].Baseline.recommendations)
        {
            $ExtensionsBaseline = @($CurrentManifestFiles[$VSCodeExtensionsRelativePath].Baseline.recommendations)
        }
        $SettingsBaseline = @{}
        if ($CurrentManifestFiles.ContainsKey($VSCodeSettingsRelativePath) -and $CurrentManifestFiles[$VSCodeSettingsRelativePath].Baseline)
        {
            $SettingsBaseline = $CurrentManifestFiles[$VSCodeSettingsRelativePath].Baseline
        }
        $ExtensionsConflict = $false
        $ExtensionsConflictReason = $null
        $SettingsConflict = $false
        $SettingsConflictReason = $null

        if ($VSCodeExtensions.Count -gt 0)
        {
            $OursExtensionIDs = @($VSCodeExtensions.ExtensionID | Select-Object -Unique)
            try
            {
                $ExtensionsMergeResult = Merge-BrownserveSetContribution `
                    -Disk $DiskVSCodeExtensionIDs `
                    -Baseline $ExtensionsBaseline `
                    -Ours $OursExtensionIDs `
                    -Force:$Force `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to merge VS Code recommended extensions.`n$($_.Exception.Message)"
            }
            if ($ExtensionsMergeResult.Conflict)
            {
                $ExtensionsConflict = $true
                $ExtensionsConflictReason = "The following recommended VS Code extensions have been removed since they were last generated: $($ExtensionsMergeResult.ConflictItems -join ', ')"
                $VSCodeWorkspaceExtensionIDs = $DiskVSCodeExtensionIDs
            }
            else
            {
                $VSCodeWorkspaceExtensionIDs = $ExtensionsMergeResult.Merged
            }
            $ExtensionsBaseline = @($OursExtensionIDs | Sort-Object)

            <#
                Due to the way we store the VS Code settings, they end up getting read out as an array
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

            try
            {
                $SettingsMergeResult = Merge-BrownserveKeyedContribution `
                    -Disk $DiskVSCodeSettings `
                    -Baseline $SettingsBaseline `
                    -Ours $VSCodeExtensionSettings `
                    -Force:$Force `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to merge repository VS code settings.`n$($_.Exception.Message)"
            }
            if ($SettingsMergeResult.Conflict)
            {
                $SettingsConflict = $true
                $SettingsConflictReason = "The following VS Code settings have been modified since they were last generated: $($SettingsMergeResult.ConflictKeys -join ', ')"
                $VSCodeWorkspaceSettings = $DiskVSCodeSettings
            }
            else
            {
                <#
                    Once we've merged the settings we like to ensure that they are sorted alphabetically.
                    This ensures that the settings file is easier to read and also makes it easier to spot any discrepancies.
                #>
                $VSCodeWorkspaceSettings = ConvertTo-SortedHashtable $SettingsMergeResult.Merged
            }
            $SettingsBaseline = ConvertTo-SortedHashtable $VSCodeExtensionSettings
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
        try
        {
            $NewGeneratedInitBefore = (Split-BrownserveContentAtMarker -Content $NewInitScriptContent.Content -Marker '### Start user defined _init steps' -ErrorAction 'Stop').Before
            $NewGeneratedInitAfter = (Split-BrownserveContentAtMarker -Content $NewInitScriptContent.Content -Marker '### End user defined _init steps' -ErrorAction 'Stop').After
            $NewGeneratedInit = @($NewGeneratedInitBefore) + @($NewGeneratedInitAfter)
        }
        catch
        {
            throw "Failed to extract the generated section of the _init.ps1 template.`n$($_.Exception.Message)"
        }
        $InitConflict = $false
        $InitConflictReason = $null
        $InitRecordedHash = $null
        if ($CurrentManifestFiles.ContainsKey($InitRelativePath))
        {
            $InitRecordedHash = $CurrentManifestFiles[$InitRelativePath].Hash
        }
        if ((Test-BrownserveMarkerConflict -DiskGenerated $DiskGeneratedInit -RecordedHash $InitRecordedHash -NewGenerated $NewGeneratedInit) -and !$Force)
        {
            $InitConflict = $true
            $InitConflictReason = 'The generated section of _init.ps1 has been modified since it was last generated and would be overwritten.'
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
        $NewGeneratedGitIgnores = (Split-BrownserveContentAtMarker -Content $NewGitIgnoresContent.Content -Marker '## Manually defined ignores: ##' -ErrorAction 'Stop').Before
        $GitIgnoreConflict = $false
        $GitIgnoreConflictReason = $null
        $GitIgnoreRecordedHash = $null
        if ($CurrentManifestFiles.ContainsKey($GitIgnoreRelativePath))
        {
            $GitIgnoreRecordedHash = $CurrentManifestFiles[$GitIgnoreRelativePath].Hash
        }
        if ((Test-BrownserveMarkerConflict -DiskGenerated $DiskGeneratedGitIgnores -RecordedHash $GitIgnoreRecordedHash -NewGenerated $NewGeneratedGitIgnores) -and !$Force)
        {
            $GitIgnoreConflict = $true
            $GitIgnoreConflictReason = 'The generated section of .gitignore has been modified since it was last generated and would be overwritten.'
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
            $dotnetToolsGeneratedLines = Get-Content -Path $dotnetToolsTempPath -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to generate dotnet tools manifest.`n$($_.Exception.Message)"
        }

        $DotnetToolsRelativePath = '.config/dotnet-tools.json'
        $DotnetToolsBaseline = @{}
        if ($CurrentManifestFiles.ContainsKey($DotnetToolsRelativePath) -and $CurrentManifestFiles[$DotnetToolsRelativePath].Baseline)
        {
            $DotnetToolsBaseline = $CurrentManifestFiles[$DotnetToolsRelativePath].Baseline
        }
        $DotnetToolsConflict = $false
        $DotnetToolsConflictReason = $null
        $GeneratedDotnetTools = Get-Content -Path $dotnetToolsTempPath -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
        $OursDotnetTools = @{}
        foreach ($ToolName in $GeneratedDotnetTools.tools.Keys)
        {
            $OursDotnetTools[$ToolName] = $GeneratedDotnetTools.tools[$ToolName]
        }

        if (Test-Path $dotnetToolsPath)
        {
            try
            {
                $ExistingDotnetTools = Get-Content -Path $dotnetToolsPath -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                if (!$ExistingDotnetTools.ContainsKey('tools'))
                {
                    throw "Missing 'tools' key"
                }
            }
            catch
            {
                if (Test-BrownserveRecordedAsMerged $DotnetToolsRelativePath)
                {
                    throw "The '$dotnetToolsPath' file is damaged and can't be parsed.`n$($_.Exception.Message)"
                }
                $UnParsableFiles += $dotnetToolsPath
                $ExistingDotnetTools = $null
            }

            if ($ExistingDotnetTools)
            {
                $DiskDotnetTools = @{}
                foreach ($ToolName in $ExistingDotnetTools.tools.Keys)
                {
                    $DiskDotnetTools[$ToolName] = $ExistingDotnetTools.tools[$ToolName]
                }

                $DotnetToolsMergeResult = Merge-BrownserveKeyedContribution `
                    -Disk $DiskDotnetTools `
                    -Baseline $DotnetToolsBaseline `
                    -Ours $OursDotnetTools `
                    -Force:$Force `
                    -ErrorAction 'Stop'

                if ($DotnetToolsMergeResult.Conflict)
                {
                    $DotnetToolsConflict = $true
                    $DotnetToolsConflictReason = "The following dotnet tools have been modified since they were last generated: $($DotnetToolsMergeResult.ConflictKeys -join ', ')"
                    $NewDotnetToolsContent = Get-BrownserveContent -Path $dotnetToolsPath -ErrorAction 'Stop'
                }
                else
                {
                    $SortedTools = [ordered]@{}
                    foreach ($ToolName in ($DotnetToolsMergeResult.Merged.Keys | Sort-Object))
                    {
                        $SortedTools[$ToolName] = $DotnetToolsMergeResult.Merged[$ToolName]
                    }
                    $MergedDotnetToolsManifest = [ordered]@{
                        version = $ExistingDotnetTools.version
                        isRoot  = $ExistingDotnetTools.isRoot
                        tools   = $SortedTools
                    }
                    $NewDotnetToolsContent = $MergedDotnetToolsManifest | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
                }
            }
        }
        if (!$NewDotnetToolsContent)
        {
            $NewDotnetToolsContent = [pscustomobject]@{ Content = $dotnetToolsGeneratedLines }
        }
        $SortedOursDotnetTools = [ordered]@{}
        foreach ($ToolName in ($OursDotnetTools.Keys | Sort-Object))
        {
            $SortedOursDotnetTools[$ToolName] = $OursDotnetTools[$ToolName]
        }
        $DotnetToolsBaseline = $SortedOursDotnetTools

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
            $NewGeneratedPaket = (Split-BrownserveContentAtMarker -Content $NewPaketDependenciesContent.Content -Marker '## Manually defined dependencies: ##' -ErrorAction 'Stop').Before
            $PaketConflict = $false
            $PaketConflictReason = $null
            $PaketRecordedHash = $null
            if ($CurrentManifestFiles.ContainsKey($PaketDependenciesRelativePath))
            {
                $PaketRecordedHash = $CurrentManifestFiles[$PaketDependenciesRelativePath].Hash
            }
            if ((Test-BrownserveMarkerConflict -DiskGenerated $DiskGeneratedPaket -RecordedHash $PaketRecordedHash -NewGenerated $NewGeneratedPaket) -and !$Force)
            {
                $PaketConflict = $true
                $PaketConflictReason = 'The generated section of paket.dependencies has been modified since it was last generated and would be overwritten.'
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

        $EditorConfigRelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $EditorConfigPath) -replace '\\', '/'
        $EditorConfigBaseline = @{}
        if ($CurrentManifestFiles.ContainsKey($EditorConfigRelativePath) -and $CurrentManifestFiles[$EditorConfigRelativePath].Baseline)
        {
            $EditorConfigBaseline = $CurrentManifestFiles[$EditorConfigRelativePath].Baseline
        }
        $EditorConfigConflict = $false
        $EditorConfigConflictReason = $null

        if ($EditorConfigParams)
        {
            # Try to preserve any manual changes that may have been made to the editorconfig file
            $DiskEditorConfigSections = @()
            if (Test-Path $EditorConfigPath)
            {
                try
                {
                    $ManualEditorConfig = Read-BrownserveEditorConfig -Path $EditorConfigPath -ErrorAction 'Stop'
                    $EditorConfigDiskContent = (Get-BrownserveContent -Path $EditorConfigPath -ErrorAction 'Stop').Content
                    $DiskGeneratedEditorConfigLines = (Split-BrownserveContentAtMarker -Content $EditorConfigDiskContent -Marker '# MANUAL CHANGES BELOW THIS LINE WILL BE PRESERVED' -ErrorAction 'Stop').Before
                    $DiskEditorConfigSections = ConvertFrom-BrownserveEditorConfigText -Content $DiskGeneratedEditorConfigLines
                }
                catch
                {
                    if (Test-BrownserveRecordedAsMerged $EditorConfigRelativePath)
                    {
                        throw "The generated section of '$EditorConfigPath' is damaged and can't be parsed.`n$($_.Exception.Message)"
                    }
                    $UnParsableFiles += $EditorConfigPath
                }
            }
            if ($ManualEditorConfig)
            {
                $EditorConfigParams.Add('ManualSection', $ManualEditorConfig)
            }

            $DiskEditorConfigFlat = @{}
            foreach ($Sec in $DiskEditorConfigSections)
            {
                foreach ($PropName in $Sec.Properties.Keys)
                {
                    $DiskEditorConfigFlat["$($Sec.Section)::$PropName"] = $Sec.Properties[$PropName]
                }
            }
            $OursEditorConfigFlat = [ordered]@{}
            foreach ($Sec in $FinalEditorConfig)
            {
                foreach ($Prop in $Sec.Properties)
                {
                    $OursEditorConfigFlat["$($Sec.FilePath)::$($Prop.Name)"] = "$($Prop.Value)".ToLower()
                }
            }

            try
            {
                $EditorConfigMergeResult = Merge-BrownserveKeyedContribution `
                    -Disk $DiskEditorConfigFlat `
                    -Baseline $EditorConfigBaseline `
                    -Ours $OursEditorConfigFlat `
                    -Force:$Force `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to merge .editorconfig contributions.`n$($_.Exception.Message)"
            }

            if ($EditorConfigMergeResult.Conflict)
            {
                $EditorConfigConflict = $true
                $ReadableConflictKeys = $EditorConfigMergeResult.ConflictKeys | ForEach-Object { $_ -replace '::', ': ' }
                $EditorConfigConflictReason = "The following .editorconfig settings have been modified since they were last generated: $($ReadableConflictKeys -join ', ')"
                if (Test-Path $EditorConfigPath)
                {
                    $NewEditorConfigContent = Get-BrownserveContent -Path $EditorConfigPath -ErrorAction 'Stop'
                }
                else
                {
                    $NewEditorConfigContent = [pscustomobject]@{ Content = @() }
                }
            }
            elseif (@(Compare-Object -ReferenceObject @($OursEditorConfigFlat.Keys) -DifferenceObject @($EditorConfigMergeResult.Merged.Keys)).Count -eq 0)
            {
                try
                {
                    $NewEditorConfigContent = New-BrownserveEditorConfig @EditorConfigParams -ErrorAction 'Stop'
                }
                catch
                {
                    throw "Failed to create .editorconfig file content.`n$($_.Exception.Message)"
                }
            }
            else
            {
                $SectionOrder = [System.Collections.Generic.List[string]]::new()
                $SectionProps = @{}
                foreach ($Sec in $FinalEditorConfig)
                {
                    if (!$SectionOrder.Contains($Sec.FilePath))
                    {
                        $SectionOrder.Add($Sec.FilePath)
                        $SectionProps[$Sec.FilePath] = [System.Collections.Generic.List[string]]::new()
                    }
                    foreach ($Prop in $Sec.Properties)
                    {
                        $Key = "$($Sec.FilePath)::$($Prop.Name)"
                        if ($EditorConfigMergeResult.Merged.Contains($Key) -and !$SectionProps[$Sec.FilePath].Contains($Prop.Name))
                        {
                            $SectionProps[$Sec.FilePath].Add($Prop.Name)
                        }
                    }
                }
                foreach ($Sec in $DiskEditorConfigSections)
                {
                    foreach ($PropName in $Sec.Properties.Keys)
                    {
                        $Key = "$($Sec.Section)::$PropName"
                        if ($EditorConfigMergeResult.Merged.Contains($Key))
                        {
                            if (!$SectionOrder.Contains($Sec.Section))
                            {
                                $SectionOrder.Add($Sec.Section)
                                $SectionProps[$Sec.Section] = [System.Collections.Generic.List[string]]::new()
                            }
                            if (!$SectionProps[$Sec.Section].Contains($PropName))
                            {
                                $SectionProps[$Sec.Section].Add($PropName)
                            }
                        }
                    }
                }
                $ReconstructedLines = [System.Collections.Generic.List[string]]::new()
                $ReconstructedLines.Add('# EditorConfig Helps Developers Define and Maintain Consistent Coding Styles Between Different Editors and IDEs.')
                $ReconstructedLines.Add('# For more information about the file format, see http://EditorConfig.org.')
                $ReconstructedLines.Add('')
                $ReconstructedLines.Add('# WARNING: THIS FILE IS MANAGED BY A TOOL, MANUAL CHANGES MAY BE LOST UNLESS IN THE DEDICATED SECTION BELOW')
                $ReconstructedLines.Add('')
                $ReconstructedLines.Add('# AUTOGENERATED EDITORCONFIG STARTS HERE')
                $ReconstructedLines.Add('')
                if ($EditorConfigParams.IncludeRoot)
                {
                    $ReconstructedLines.Add('# top-most EditorConfig file')
                    $ReconstructedLines.Add('root = true')
                    $ReconstructedLines.Add('')
                }
                for ($i = 0; $i -lt $SectionOrder.Count; $i++)
                {
                    $Sec = $SectionOrder[$i]
                    $ReconstructedLines.Add("[$Sec]")
                    foreach ($PropName in $SectionProps[$Sec])
                    {
                        $ReconstructedLines.Add("$PropName = $($EditorConfigMergeResult.Merged["${Sec}::${PropName}"])")
                    }
                    if ($i -lt $SectionOrder.Count - 1)
                    {
                        $ReconstructedLines.Add('')
                    }
                }
                $ReconstructedLines.Add('')
                $ReconstructedLines.Add('# MANUAL CHANGES BELOW THIS LINE WILL BE PRESERVED')
                if ($ManualEditorConfig)
                {
                    $ManualEditorConfig | ForEach-Object { $ReconstructedLines.Add($_) }
                }
                $NewEditorConfigContent = $ReconstructedLines.ToArray() | Format-BrownserveContent
            }
            $SortedEditorConfigBaseline = [ordered]@{}
            foreach ($FlatKey in ($OursEditorConfigFlat.Keys | Sort-Object))
            {
                $SortedEditorConfigBaseline[$FlatKey] = $OursEditorConfigFlat[$FlatKey]
            }
            $EditorConfigBaseline = $SortedEditorConfigBaseline
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

        # The license we generate is tied to the ReleaseLifecycle component
        # though in the future we may want to allow the user to override this.
        if ($LicenseType)
        {
            $NewLicenseContent = New-SPDXLicense `
                -LicenseType $LicenseType `
                -Owner $Owner `
                -ErrorAction 'Stop' | Format-BrownserveContent
        }


        try
        {
            $NewNugetConfig = Get-BrownserveContent -Path $NugetConfigTempPath -ErrorAction 'Stop'
            if ($NewNugetConfig.Content.Count -gt 0 -and $NewNugetConfig.Content[-1] -ne '')
            {
                $NewNugetConfig.Content += ''
            }
        }
        catch
        {
            throw "Failed to process '$NugetConfigPath'.`n$($_.Exception.Message)"
        }
        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path      = $NugetConfigPath
                Ownership = [BrownserveFileOwnership]::Managed
                Component = 'Core'
                Content   = $NewNugetConfig.Content
            })

        if (!(Test-Path $dotnetToolsConfigPath) -and ($MissingDirectories.Path -notcontains $dotnetToolsConfigPath))
        {
            $MissingDirectories += [pscustomobject]@{
                Path = $dotnetToolsConfigPath
            }
        }
        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path                    = $dotnetToolsPath
                Ownership               = [BrownserveFileOwnership]::Merged
                Component               = 'Core'
                Content                 = $NewDotnetToolsContent.Content
                StructuredContributions = $DotnetToolsBaseline
                Conflict                = $DotnetToolsConflict
                ConflictReason          = $DotnetToolsConflictReason
            })

        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path           = $InitPath
                Ownership      = [BrownserveFileOwnership]::Merged
                Component      = 'Core'
                Content        = $NewInitScriptContent.Content
                MarkerSection  = @{ Generated = $NewGeneratedInit }
                Conflict       = $InitConflict
                ConflictReason = $InitConflictReason
            })

        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path           = $GitIgnorePath
                Ownership      = [BrownserveFileOwnership]::Merged
                Component      = 'Core'
                Content        = $NewGitIgnoresContent.Content
                MarkerSection  = @{ Generated = $NewGeneratedGitIgnores }
                Conflict       = $GitIgnoreConflict
                ConflictReason = $GitIgnoreConflictReason
            })

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
        }
        catch
        {
            throw "Failed to process '$VSCodeExtensionsFilePath'.`n$($_.Exception.Message)"
        }
        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path                    = $VSCodeExtensionsFilePath
                Ownership               = [BrownserveFileOwnership]::Merged
                Component               = 'Core'
                Content                 = $VSCodeWorkspaceExtensionIDsJSON.Content
                StructuredContributions = @{ recommendations = $ExtensionsBaseline }
                Conflict                = $ExtensionsConflict
                ConflictReason          = $ExtensionsConflictReason
            })

        try
        {
            $VSCodeWorkspaceSettingsJSON = ConvertTo-Json `
                -InputObject $VSCodeWorkspaceSettings `
                -Depth 100 `
                -ErrorAction 'Stop' | Format-BrownserveContent
        }
        catch
        {
            throw "Failed to process '$VSCodeWorkspaceSettingsFilePath'.`n$($_.Exception.Message)"
        }
        $ManagedFiles.Add([BrownserveManagedFile]@{
                Path                    = $VSCodeWorkspaceSettingsFilePath
                Ownership               = [BrownserveFileOwnership]::Merged
                Component               = 'Core'
                Content                 = $VSCodeWorkspaceSettingsJSON.Content
                StructuredContributions = $SettingsBaseline
                Conflict                = $SettingsConflict
                ConflictReason          = $SettingsConflictReason
            })

        if ($NewPaketDependenciesContent)
        {
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path           = $PaketDependenciesPath
                    Ownership      = [BrownserveFileOwnership]::Merged
                    Component      = 'Core'
                    Content        = $NewPaketDependenciesContent.Content
                    MarkerSection  = @{ Generated = $NewGeneratedPaket }
                    Conflict       = $PaketConflict
                    ConflictReason = $PaketConflictReason
                })
        }

        if ($Devcontainer)
        {
            # Devcontainer can't exist if the parent directory doesn't exist!
            if (!(Test-Path $DevcontainerDirectoryPath) -and ($MissingDirectories.Path -notcontains $DevcontainerDirectoryPath))
            {
                $MissingDirectories += [pscustomobject]@{
                    Path = $DevcontainerDirectoryPath
                }
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $DevcontainerPath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'Core'
                    Content   = $Devcontainer.Devcontainer.Content
                })
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $DockerfilePath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'Core'
                    Content   = $Devcontainer.Dockerfile.Content
                })
        }

        if ($NewEditorConfigContent)
        {
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path                    = $EditorConfigPath
                    Ownership               = [BrownserveFileOwnership]::Merged
                    Component               = 'Core'
                    Content                 = $NewEditorConfigContent.Content
                    StructuredContributions = $EditorConfigBaseline
                    Conflict                = $EditorConfigConflict
                    ConflictReason          = $EditorConfigConflictReason
                })
        }

        <#
            For the changelog we only ever create it if it doesn't already exist.
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
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $ChangelogPath
                    Ownership = [BrownserveFileOwnership]::Seeded
                    Component = 'ReleaseLifecycle'
                    Content   = $NewChangelogContent.Content
                })
        }

        <#
            We don't ever want to overwrite the license file if it already exists, any changes to the license file
            should be made manually for legal reasons.
        #>
        if ($LicenseType)
        {
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $LicensePath
                    Ownership = [BrownserveFileOwnership]::Seeded
                    Component = 'ReleaseLifecycle'
                    Content   = $NewLicenseContent.Content
                })
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
            }
            catch
            {
                throw "Failed to process '$MarkdownlintConfigPath'.`n$($_.Exception.Message)"
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $MarkdownlintConfigPath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'ReleaseLifecycle'
                    Content   = $NewMarkdownlintContent.Content
                })
        }

        if ($ModuleInfo)
        {
            $ModuleInfoPath = Join-Path $BuildDirectory 'ModuleInfo.json'
            if (!(Test-Path $ModuleInfoPath))
            {
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
                }
                catch
                {
                    throw "Failed to generate ModuleInfo.json content.`n$($_.Exception.Message)"
                }
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $ModuleInfoPath
                    Ownership = [BrownserveFileOwnership]::Seeded
                    Component = 'PowerShellModule'
                    Content   = $NewModuleInfoContent.Content
                })
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

            try
            {
                if ($WorkflowTemplateParams)
                {
                    $WorkflowTemplateParams.Builds.Substitutions['REPO_NAME']       = $RepoName
                    $WorkflowTemplateParams.StageRelease.Substitutions['REPO_NAME'] = $RepoName
                    $WorkflowTemplateParams.Release.Substitutions['REPO_NAME']      = $RepoName
                    $BuildsTemplateParams       = $WorkflowTemplateParams.Builds
                    $StageReleaseTemplateParams = $WorkflowTemplateParams.StageRelease
                    $ReleaseTemplateParams      = $WorkflowTemplateParams.Release
                    $NewBuildsWorkflowContent       = New-BrownserveContentFromTemplate @BuildsTemplateParams | Format-BrownserveContent
                    $NewStageReleaseWorkflowContent = New-BrownserveContentFromTemplate @StageReleaseTemplateParams | Format-BrownserveContent
                    $NewReleaseWorkflowContent      = New-BrownserveContentFromTemplate @ReleaseTemplateParams | Format-BrownserveContent
                }
                else
                {
                    $WorkflowCommonParams = @{ ModuleName = $ModuleInfo.Name; RepoName = $RepoName }
                    $NewBuildsWorkflowContent       = New-BrownserveGitHubBuildsWorkflow -ModuleName $ModuleInfo.Name -RepoName $RepoName | Format-BrownserveContent
                    $NewStageReleaseWorkflowContent = New-BrownserveGitHubStageReleaseWorkflow @WorkflowCommonParams | Format-BrownserveContent
                    $NewReleaseWorkflowContent      = New-BrownserveGitHubReleaseWorkflow @WorkflowCommonParams | Format-BrownserveContent
                }
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
                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path      = $WorkflowFile.Path
                        Ownership = [BrownserveFileOwnership]::Managed
                        Component = 'ReleaseLifecycle'
                        Content   = $WorkflowFile.Content.Content
                    })
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
            }
            catch
            {
                throw "Failed to process '$LabelPRWorkflowPath'.`n$($_.Exception.Message)"
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $LabelPRWorkflowPath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'ReleaseLifecycle'
                    Content   = $NewLabelPRWorkflowContent.Content
                })
        }

        if ($IncludeContributing)
        {
            $ContributingPath = Join-Path $GitHubDirectory 'CONTRIBUTING.md'

            if (!(Test-Path $GitHubDirectory) -and ($MissingDirectories.Path -notcontains $GitHubDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $GitHubDirectory }
            }

            try
            {
                $NewContributingContent = New-BrownserveContentFromTemplate @ContributingParams | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to process '$ContributingPath'.`n$($_.Exception.Message)"
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $ContributingPath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'ReleaseLifecycle'
                    Content   = $NewContributingContent.Content
                })
        }

        if ($IncludePRTemplate)
        {
            if (-not $RepoName)
            {
                $RepoName = Split-Path $RepositoryPath -Leaf
            }

            $PRTemplatePath = Join-Path $GitHubDirectory 'pull_request_template.md'

            if (!(Test-Path $GitHubDirectory) -and ($MissingDirectories.Path -notcontains $GitHubDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $GitHubDirectory }
            }

            try
            {
                $PRTemplateParams.Substitutions['REPO_NAME'] = $RepoName
                if ($PRTemplateParams.Substitutions.ContainsKey('OWNER'))
                {
                    $PRTemplateParams.Substitutions['OWNER'] = $Owner
                }
                $NewPRTemplateContent = New-BrownserveContentFromTemplate @PRTemplateParams | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to process '$PRTemplatePath'.`n$($_.Exception.Message)"
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $PRTemplatePath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'ReleaseLifecycle'
                    Content   = $NewPRTemplateContent.Content
                })
        }

        if ($IncludeBuildScripts)
        {
            $BuildScriptPath = Join-Path $BuildDirectory 'build.ps1'
            $BuildTasksScriptPath = Join-Path $BuildTasksDirectory 'build_tasks.ps1'

            try
            {
                if ($BuildScriptTemplateParams)
                {
                    if (-not $RepoName)
                    {
                        $RepoName = Split-Path $RepositoryPath -Leaf
                    }
                    $BuildScriptTemplateParams.BuildScript.Substitutions['REPO_NAME'] = $RepoName
                    $BuildScriptTemplateParams.BuildTasks.Substitutions['REPO_NAME']  = $RepoName
                    if ($BuildScriptTemplateParams.BuildScript.Substitutions.ContainsKey('OWNER'))
                    {
                        $BuildScriptTemplateParams.BuildScript.Substitutions['OWNER'] = $Owner
                    }
                    $BuildScriptParams = $BuildScriptTemplateParams.BuildScript
                    $BuildTasksParams  = $BuildScriptTemplateParams.BuildTasks
                    $NewBuildScriptContent      = New-BrownserveContentFromTemplate @BuildScriptParams | Format-BrownserveContent
                    $NewBuildTasksScriptContent = New-BrownserveContentFromTemplate @BuildTasksParams | Format-BrownserveContent
                }
                else
                {
                    $LegacyBuildScriptParams = @{}
                    if ($BuildScriptUseWorkingCopyOption)
                    {
                        $LegacyBuildScriptParams['IncludeUseWorkingCopyOption'] = $true
                    }
                    $NewBuildScriptContent      = New-BrownserveBuildScript @LegacyBuildScriptParams -Owner $Owner | Format-BrownserveContent
                    $NewBuildTasksScriptContent = New-BrownserveBuildTasksScript @LegacyBuildScriptParams | Format-BrownserveContent
                }
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
                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path      = $BuildFile.Path
                        Ownership = [BrownserveFileOwnership]::Managed
                        Component = 'ReleaseLifecycle'
                        Content   = $BuildFile.Content.Content
                    })
            }
        }

        if ($IncludePesterTests)
        {
            $BuildTestsDirectory = Join-Path $BuildDirectory 'tests'

            if (-not $RepoName)
            {
                $RepoName = Split-Path $RepositoryPath -Leaf
            }

            if (!(Test-Path $BuildTestsDirectory) -and ($MissingDirectories.Path -notcontains $BuildTestsDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $BuildTestsDirectory }
            }

            foreach ($TestSpec in $PesterTestsParams)
            {
                $PesterTestPath = Join-Path $BuildTestsDirectory $TestSpec.FileName

                if ($TestSpec.Substitutions.ContainsKey('REPO_NAME'))
                {
                    $TestSpec.Substitutions['REPO_NAME'] = $RepoName
                }

                try
                {
                    $TestSplatParams = @{
                        TemplateDirectory = $TestSpec.TemplateDirectory
                        TemplateName      = $TestSpec.TemplateName
                        Substitutions     = $TestSpec.Substitutions
                    }
                    $NewPesterTestContent = New-BrownserveContentFromTemplate @TestSplatParams | Format-BrownserveContent
                }
                catch
                {
                    throw "Failed to generate '$($TestSpec.FileName)' content.`n$($_.Exception.Message)"
                }
                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path      = $PesterTestPath
                        Ownership = [BrownserveFileOwnership]::Managed
                        Component = 'ReleaseLifecycle'
                        Content   = $NewPesterTestContent.Content
                    })
            }
        }

        if ($IncludeInstallScripts)
        {
            $ScriptsDirectory = Join-Path $RepositoryPath 'scripts'

            if (!(Test-Path $ScriptsDirectory) -and ($MissingDirectories.Path -notcontains $ScriptsDirectory))
            {
                $MissingDirectories += [pscustomobject]@{ Path = $ScriptsDirectory }
            }

            $InstallScriptsParams = @{
                ShellScript      = @{
                    TemplateDirectory = $TemplatesDirectory
                    TemplateName      = 'rustapp_install.sh.template'
                    Substitutions     = @{ REPO_NAME = $RepoName; OWNER = $Owner }
                }
                PowerShellScript = @{
                    TemplateDirectory = $TemplatesDirectory
                    TemplateName      = 'rustapp_install.ps1.template'
                    Substitutions     = @{ REPO_NAME = $RepoName; OWNER = $Owner }
                }
            }

            try
            {
                $ShellScriptParams      = $InstallScriptsParams.ShellScript
                $PSScriptParams         = $InstallScriptsParams.PowerShellScript
                $NewInstallShContent    = New-BrownserveContentFromTemplate @ShellScriptParams   | Format-BrownserveContent
                $NewInstallPS1Content   = New-BrownserveContentFromTemplate @PSScriptParams      | Format-BrownserveContent
            }
            catch
            {
                throw "Failed to generate install script content.`n$($_.Exception.Message)"
            }

            $InstallFiles = @(
                @{ Path = (Join-Path $ScriptsDirectory 'install.sh');  Content = $NewInstallShContent },
                @{ Path = (Join-Path $ScriptsDirectory 'install.ps1'); Content = $NewInstallPS1Content }
            )
            foreach ($InstallFile in $InstallFiles)
            {
                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path      = $InstallFile.Path
                        Ownership = [BrownserveFileOwnership]::Managed
                        Component = 'RustBinary'
                        Content   = $InstallFile.Content.Content
                    })
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
                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path      = $MkDocsFile.Path
                        Ownership = [BrownserveFileOwnership]::Managed
                        Component = 'MkDocs'
                        Content   = $MkDocsFile.Content.Content
                    })
            }
        }
    }
    end
    {
        if ($IncludeAstroDocs)
        {
            if (-not $RepoName)
            {
                $RepoName = Split-Path $RepositoryPath -Leaf
            }
            $AstroDirectory      = Join-Path $RepositoryPath 'pages'
            $AstroSrcDirectory   = Join-Path $AstroDirectory 'src'
            $AstroPagesDirectory = Join-Path $AstroSrcDirectory 'pages'

            foreach ($Dir in @($AstroDirectory, $AstroSrcDirectory, $AstroPagesDirectory))
            {
                if (!(Test-Path $Dir) -and ($MissingDirectories.Path -notcontains $Dir))
                {
                    $MissingDirectories += [pscustomobject]@{ Path = $Dir }
                }
            }

            $AstroSubstitutions = @{
                REPO_NAME   = $RepoName
                OWNER_LOWER = $Owner.ToLower()
            }

            $AstroFiles = @(
                @{ Path = (Join-Path $AstroDirectory 'package.json');        TemplateName = 'skillsrepo_astro_package.json.template'; Ownership = [BrownserveFileOwnership]::Merged },
                @{ Path = (Join-Path $AstroDirectory 'astro.config.mjs');    TemplateName = 'skillsrepo_astro_config.mjs.template';   Ownership = [BrownserveFileOwnership]::Managed },
                @{ Path = (Join-Path $AstroPagesDirectory 'index.astro');    TemplateName = 'skillsrepo_astro_index.astro.template';  Ownership = [BrownserveFileOwnership]::Seeded }
            )

            foreach ($AstroFile in $AstroFiles)
            {
                if ($AstroFile.Ownership -eq [BrownserveFileOwnership]::Seeded -and (Test-Path $AstroFile.Path))
                {
                    $ManagedFiles.Add([BrownserveManagedFile]@{
                            Path      = $AstroFile.Path
                            Ownership = $AstroFile.Ownership
                            Component = 'AstroDocs'
                        })
                    continue
                }

                try
                {
                    $NewAstroContent = New-BrownserveContentFromTemplate `
                        -TemplateDirectory $TemplatesDirectory `
                        -TemplateName $AstroFile.TemplateName `
                        -Substitutions $AstroSubstitutions `
                        -ErrorAction 'Stop' | Format-BrownserveContent
                }
                catch
                {
                    throw "Failed to process '$($AstroFile.Path)'.`n$($_.Exception.Message)"
                }

                $PackageJsonConflict = $false
                $PackageJsonConflictReason = $null
                $PackageJsonBaseline = @{}
                if ($AstroFile.Ownership -eq [BrownserveFileOwnership]::Merged)
                {
                    $PackageJsonRelativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $AstroFile.Path) -replace '\\', '/'
                    $DiskPackageJsonBaseline = @{}
                    if ($CurrentManifestFiles.ContainsKey($PackageJsonRelativePath) -and $CurrentManifestFiles[$PackageJsonRelativePath].Baseline)
                    {
                        $DiskPackageJsonBaseline = $CurrentManifestFiles[$PackageJsonRelativePath].Baseline
                    }
                    $GeneratedPackageJson = ($NewAstroContent.Content -join "`n") | ConvertFrom-Json -Depth 100 -AsHashtable
                    $OursPackageJsonFlat = ConvertTo-BrownservePackageJsonFlatMap -PackageJson $GeneratedPackageJson

                    if (Test-Path $AstroFile.Path)
                    {
                        try
                        {
                            $ExistingPackageJson = Get-Content -Path $AstroFile.Path -Raw -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
                        }
                        catch
                        {
                            if (Test-BrownserveRecordedAsMerged $PackageJsonRelativePath)
                            {
                                throw "The '$($AstroFile.Path)' file is damaged and can't be parsed.`n$($_.Exception.Message)"
                            }
                            $UnParsableFiles += $AstroFile.Path
                            $ExistingPackageJson = $null
                        }
                    }

                    if ($ExistingPackageJson)
                    {
                        $DiskPackageJsonFlat = ConvertTo-BrownservePackageJsonFlatMap -PackageJson $ExistingPackageJson
                        $PackageJsonMergeResult = Merge-BrownserveKeyedContribution `
                            -Disk $DiskPackageJsonFlat `
                            -Baseline $DiskPackageJsonBaseline `
                            -Ours $OursPackageJsonFlat `
                            -Force:$Force `
                            -ErrorAction 'Stop'

                        if ($PackageJsonMergeResult.Conflict)
                        {
                            $PackageJsonConflict = $true
                            $PackageJsonConflictReason = "The following package.json contributions have been modified since they were last generated: $($PackageJsonMergeResult.ConflictKeys -join ', ')"
                            $NewAstroContent = Get-BrownserveContent -Path $AstroFile.Path -ErrorAction 'Stop'
                        }
                        else
                        {
                            $MergedPackageJson = ConvertFrom-BrownservePackageJsonFlatMap -FlatMap $PackageJsonMergeResult.Merged
                            $NewAstroContent = $MergedPackageJson | ConvertTo-Json -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
                        }
                    }
                    $PackageJsonBaseline = $OursPackageJsonFlat
                }

                $ManagedFiles.Add([BrownserveManagedFile]@{
                        Path                    = $AstroFile.Path
                        Ownership               = $AstroFile.Ownership
                        Component               = 'AstroDocs'
                        Content                 = $NewAstroContent.Content
                        StructuredContributions = $PackageJsonBaseline
                        Conflict                = $PackageJsonConflict
                        ConflictReason          = $PackageJsonConflictReason
                    })
            }
        }

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
            }
            catch
            {
                throw "Failed to process '$DependabotPath'.`n$($_.Exception.Message)"
            }
            $ManagedFiles.Add([BrownserveManagedFile]@{
                    Path      = $DependabotPath
                    Ownership = [BrownserveFileOwnership]::Managed
                    Component = 'Core'
                    Content   = $NewDependabotContent.Content
                })
        }

        if ($UnParsableFiles.Count -gt 0 -and !$Force)
        {
            throw "The following files already exist in the repository but are in a format that can't be parsed:`n$($UnParsableFiles -join "`n")"
        }

        try
        {
            $CompareResult = Compare-BrownserveManagedFile `
                -RepositoryPath $RepositoryPath `
                -ManagedFile $ManagedFiles.ToArray() `
                -CurrentManifestFiles $CurrentManifestFiles `
                -Force:$Force `
                -ErrorAction 'Stop'
        }
        catch
        {
            throw "Failed to compare managed files against disk.`n$($_.Exception.Message)"
        }

        $MissingFiles = @($CompareResult.MissingFiles)
        $ChangedFiles = @($CompareResult.ChangedFiles)
        $ConflictedFiles = @($CompareResult.ConflictedFiles)
        $RemovedFiles = @($CompareResult.RemovedFiles)

        try
        {
            $NewManifest = New-BrownserveRepositoryManifest `
                -Components $Components `
                -ComponentOptions $ComponentOptions `
                -Definitions $ComponentDefinitions `
                -GeneratedByVersion $BrownserveModuleVersions['Brownserve.PSBuildTools'] `
                -Files $CompareResult.Files `
                -ErrorAction 'Stop'
            $NewManifestJSON = ConvertTo-Json $NewManifest -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
            if ($CurrentManifest)
            {
                Write-Verbose 'Checking for changes to repository manifest'
                $CurrentManifestJSON = ConvertTo-Json $CurrentManifest -Depth 100 -ErrorAction 'Stop' | Format-BrownserveContent
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

        # Return an object that contains all the information we've gathered
        $Return = [pscustomobject]@{
            MissingFiles       = $MissingFiles
            ChangedFiles       = $ChangedFiles
            ConflictedFiles    = $ConflictedFiles
            RemovedFiles       = $RemovedFiles
            MissingDirectories = $MissingDirectories
            ManifestPath       = $ManifestPath
        }
        Return $Return
    }
}
