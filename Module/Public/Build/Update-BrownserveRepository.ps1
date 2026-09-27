<#
.SYNOPSIS
    Updates a repository that has already been initialised with 'Initialize-BrownserveRepository'.
.DESCRIPTION
    Reads the repository's '.brownserve_repository_manifest' to work out which components it's configured with.
    A v1 (legacy, project-type based) manifest is migrated automatically to the v2, component based format,
    carrying over the working-copy setting for PowerShell module repositories where appropriate.
    A file the manifest owns that has been manually edited since it was last generated is reported as a
    conflict and stops the whole run, before any files are written, unless '-Force' is passed.
.PARAMETER RepositoryPath
    The path to the repository to update. Defaults to the current directory.
.PARAMETER Owner
    The owner of the repository, used for licensing and other metadata.
.PARAMETER Force
    Forces the recreation of files even if they already exist.
.PARAMETER RepoName
    The GitHub repository name, if different from the local directory name.
.EXAMPLE
    Update-BrownserveRepository
    Updates the repository in the current directory.
#>
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
        $RepoName
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
            Start by loading our special repository manifest file so we know what components we're working with
        #>
        $RepositoryManifestFile = Join-Path $RepositoryPath '.brownserve_repository_manifest'
        if (!(Test-Path $RepositoryManifestFile))
        {
            throw "Repository manifest file not found at '$RepositoryManifestFile'.`nPlease run 'Initialize-BrownserveRepository' first."
        }
        try
        {
            $Manifest = Get-Content $RepositoryManifestFile -ErrorAction 'Stop' | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        catch
        {
            throw "Failed to read repository manifest file.`n$($_.Exception.Message)"
        }

        $ModuleInfoPath = Join-Path $RepositoryPath '.build' 'ModuleInfo.json'
        $ExistingModuleInfo = $null
        if (Test-Path $ModuleInfoPath)
        {
            try
            {
                $ModuleInfoData = Get-Content $ModuleInfoPath -Raw -ErrorAction 'Stop' | ConvertFrom-Json -AsHashtable
                $ExistingModuleInfo = [BrownservePowerShellModule]$ModuleInfoData
            }
            catch
            {
                throw "Failed to load module info.`n$($_.Exception.Message)"
            }
        }

        if ($Manifest.ManifestVersion -like '2.*')
        {
            $Components = @($Manifest.Components | ForEach-Object { $_.Name })
            $ComponentOptions = @{}
            foreach ($ManifestComponent in $Manifest.Components)
            {
                if ($ManifestComponent.Options)
                {
                    $ComponentOptions[$ManifestComponent.Name] = @{} + $ManifestComponent.Options
                }
            }
            if ($Components -contains 'PowerShellModule' -and $ExistingModuleInfo)
            {
                if (!$ComponentOptions.ContainsKey('PowerShellModule'))
                {
                    $ComponentOptions['PowerShellModule'] = @{}
                }
                $ComponentOptions['PowerShellModule']['ModuleInfo'] = $ExistingModuleInfo
            }
        }
        else
        {
            Write-Verbose 'Migrating legacy (v1) repository manifest to the v2, component based format.'
            try
            {
                $Migrated = ConvertTo-BrownserveRepoComponentFromLegacyType `
                    -RepositoryType $Manifest.RepositoryType `
                    -ModuleInfo $ExistingModuleInfo `
                    -ErrorAction 'Stop'
            }
            catch
            {
                throw "Failed to migrate legacy repository manifest.`n$($_.Exception.Message)"
            }
            $Components = $Migrated.Components
            $ComponentOptions = $Migrated.ComponentOptions
        }

        try
        {
            $CompareParams = @{
                RepositoryPath   = $RepositoryPath
                Components       = $Components
                ComponentOptions = $ComponentOptions
                Owner            = $Owner
                RepoName         = $RepoName
                Force            = $Force
                ErrorAction      = 'Stop'
            }
            $RepositoryState = Compare-BrownserveRepository @CompareParams
        }
        catch
        {
            throw "Failed to get repository state.`n$($_.Exception.Message)"
        }

        if ($RepositoryState.ConflictedFiles.Count -gt 0)
        {
            $ConflictSummary = ($RepositoryState.ConflictedFiles | ForEach-Object { "$($_.Path): $($_.Reason)" }) -join "`n"
            throw "The following files have been modified since they were last generated and would be overwritten:`n$ConflictSummary`nUse the '-Force' switch to overwrite them."
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
