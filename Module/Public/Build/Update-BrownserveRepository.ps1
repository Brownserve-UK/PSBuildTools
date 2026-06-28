function Update-BrownserveRepository
{
    [CmdletBinding()]
    param
    (
        # The path to the repository
        [Parameter(Mandatory = $false, Position = 0)]
        [string]
        $RepositoryPath = (Get-Location),

        # The owner of the repository (used for licensing and other metadata)
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK',

        # Forces the recreation of files even if they already exist
        [Parameter(Mandatory = $false)]
        [switch]
        $Force,

        # The GitHub repository name, if different from the local directory name.
        # Defaults to the leaf name of RepositoryPath if not provided.
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName,

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
        $EditorConfigConfigFile = (Join-Path $Script:BrownservePSBuildToolsConfigDirectory 'editorconfig_config.json')
    )
    begin
    {
        # Ensure that dotnet is available for us to use, we need it to instal tooling and make our nuget.config
        try
        {
            $RequiredTools = @('git')
            Write-Verbose 'Checking for required tooling'
            Assert-Command $RequiredTools
        }
        catch
        {
            throw "$($_.Exception.Message)`nThese tools are required to configure a Brownserve repository."
        }
    }
    process
    {
        <#
            Start by loading our special repository manifest file so we know what type of project we're working with
        #>
        $RepositoryManifestFile = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        if (!(Test-Path $RepositoryManifestFile))
        {
            throw "Repository manifest file not found at '$RepositoryManifestFile'.`nPlease run 'Initialize-BrownserveRepository' first."
        }
        try
        {
            $RepositoryType = Get-Content $RepositoryManifestFile -ErrorAction 'Stop' |
                ConvertFrom-Json |
                    Select-Object -ExpandProperty RepositoryType
        }
        catch
        {
            throw "Failed to read repository manifest file.`n$($_.Exception.Message)"
        }
        if ($RepositoryType -in @('PowerShellModule', 'BrownservePSTools'))
        {
            try
            {
                $RepositoryPathsConfig = Read-ConfigurationFromFile $RepositoryPathsConfigFile
                $BuildDirectory = Join-Path $RepositoryPath ($RepositoryPathsConfig.Defaults.PermanentPaths |
                    Where-Object { $_.VariableName -eq 'BrownserveRepoBuildDirectory' }).Path
                $ModuleInfoPath = Join-Path $BuildDirectory 'ModuleInfo.json'
                if (!(Test-Path $ModuleInfoPath))
                {
                    throw "ModuleInfo.json not found at '$ModuleInfoPath'."
                }
                $ModuleInfoData = Get-Content $ModuleInfoPath -Raw | ConvertFrom-Json -AsHashtable
                $ModuleInfo = [BrownservePowerShellModule]$ModuleInfoData
            }
            catch
            {
                throw "Failed to load module info.`n$($_.Exception.Message)"
            }
        }

        try
        {
            $CompareParams = @{
                RepositoryPath             = $RepositoryPath
                ProjectType                = $RepositoryType
                Owner                      = $Owner
                GitIgnoreConfigFile        = $GitIgnoreConfigFile
                PaketDependenciesConfigFile = $PaketDependenciesConfigFile
                RepositoryPathsConfigFile  = $RepositoryPathsConfigFile
                DevcontainerConfigFile     = $DevcontainerConfigFile
                VSCodeExtensionsConfigFile = $VSCodeExtensionsConfigFile
                PackageAliasConfigFile     = $PackageAliasConfigFile
                EditorConfigConfigFile     = $EditorConfigConfigFile
                RepoName                  = $RepoName
                ErrorAction               = 'Stop'
            }
            if ($ModuleInfo)
            {
                $CompareParams.ModuleInfo = $ModuleInfo
            }
            $RepositoryState = Compare-BrownserveRepository @CompareParams
        }
        catch
        {
            throw "Failed to get repository state.`n$($_.Exception.Message)"
        }

        # Only proceed if we have no missing files or changes
        if (($RepositoryState.MissingFiles.Count -gt 0) -or ($RepositoryState.ChangedFiles.Count -gt 0))
        {
            Write-Debug "Changed files: $(($RepositoryState.ChangedFiles | Select-Object -ExpandProperty Path) -join "`n")"
            if ($RepositoryState.MissingFiles.Count -gt 0)
            {
                Write-Debug "Missing files: $(($RepositoryState.MissingFiles | Select-Object -ExpandProperty Path) -join "`n")"
            }
            # Check what branch we are on
            try
            {
                $CurrentBranch = Get-GitCurrentBranch -RepositoryPath $RepositoryPath
            }
            catch
            {
                throw $_.Exception.Message
            }

            # Make sure we're running on a branch
            $Today = Get-Date -Format 'yyyyMMdd'
            $TempBranchName = "brownserve_repo_update_$Today"
            if ($CurrentBranch -ne $TempBranchName)
            {
                Write-Debug "Current branch: $CurrentBranch"
                # Check to see if we've already got the branch available to use
                try
                {
                    $LocalBranches = Get-GitBranches `
                        -RepositoryPath $RepositoryPath `
                        -ErrorAction 'Stop'
                }
                catch
                {
                    # Let this silently fail and just try and create the branch anyways
                    Write-Debug "Get-GitBranches has failed with $($_.Exception.Message).`nIgnoring"
                }
                if ($LocalBranches -contains $TempBranchName)
                {
                    Write-Verbose "'$TempBranchName' already exists, attempting to checkout"
                    try
                    {
                        Switch-GitBranch `
                            -RepositoryPath $RepositoryPath `
                            -BranchName $TempBranchName `
                            -ErrorAction 'Stop'
                    }
                    catch
                    {
                        throw "The branch '$TempBranchName' already exists but git was unable to checkout this branch.`n$($_.Exception.Message)"
                    }
                }
                else
                {
                    Write-Verbose "Creating new branch '$TempBranchName'"
                    try
                    {
                        New-GitBranch `
                            -RepositoryPath $RepositoryPath `
                            -BranchName $TempBranchName `
                            -Checkout $true `
                            -ErrorAction 'Stop'
                    }
                    catch
                    {
                        throw "Failed to create working branch.`n$($_.Exception.Message)"
                    }
                }
            }

            # Start by creating any missing directories, they may be needed for the files we're about to create
            foreach ($Directory in $RepositoryState.MissingDirectories)
            {
                Write-Verbose "Creating directory '$Directory.Path)'"
                try
                {
                    New-Item `
                        -Path $Directory.Path `
                        -ItemType 'Directory' `
                        -ErrorAction 'Stop' | Out-Null
                }
                catch
                {
                    throw "Failed to create directory '$($Directory.Path)'.`n$($_.Exception.Message)"
                }
            }

            # Create any missing files
            foreach ($File in $RepositoryState.MissingFiles)
            {
                Write-Verbose "Creating file '$($File.Path)'"
                try
                {
                    New-Item `
                        -Path $File.Path `
                        -ItemType 'File' `
                        -ErrorAction 'Stop' | Out-Null

                    $File | Set-BrownserveContent -ErrorAction 'Stop'
                }
                catch
                {
                    throw "Failed to create file '$($File.Path)'.`n$($_.Exception.Message)"
                }
            }

            # Update any changed files
            foreach ($File in $RepositoryState.ChangedFiles)
            {
                Write-Verbose "Updating file '$($File.Path)'"
                try
                {
                    $File | Set-BrownserveContent -ErrorAction 'Stop'
                }
                catch
                {
                    throw "Failed to update file '$($File.Path)'.`n$($_.Exception.Message)"
                }
            }
        }
        else
        {
            Write-Verbose 'Repository does not require any updates'
        }
    }
    end
    {
    }
}
