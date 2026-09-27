<#
.SYNOPSIS
    Initialises a repository with the files needed for it to be built and released the "Brownserve way".
.DESCRIPTION
    Repositories are described by a set of components (e.g. 'PowerShellModule', 'RustBinary', 'ContainerImage')
    rather than a single project type. 'Core' is always included automatically.
    This cmdlet works out what's missing/different compared to what the requested components expect and, if
    it's safe to do so, creates/updates those files on a dedicated branch.
    A file the manifest owns that has been manually edited since it was last generated is reported as a
    conflict and stops the whole run, before any files are written, unless '-Force' is passed.
.PARAMETER RepositoryPath
    The path to the repository to initialise. Defaults to the current directory.
.PARAMETER Components
    The components this repository should be configured with. 'Core' is always included and should not be
    listed explicitly.
.PARAMETER ComponentOptions
    Options for the requested components, keyed by component name. For example, a 'PowerShellModule'
    repository's metadata is supplied via '@{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }'.
.PARAMETER RepoName
    The GitHub repository name, if different from the local directory name.
.PARAMETER Owner
    The owner of the repository, used for licensing and other metadata.
.PARAMETER Force
    Forces the recreation of files even if they already exist.
.EXAMPLE
    Initialize-BrownserveRepository -Components RustBinary
    Initialises the current directory as a Rust binary repository.
.EXAMPLE
    $ModuleInfo = @{ Name = 'Brownserve.Example'; Description = '...'; GUID = (New-Guid); Tags = @('example') }
    Initialize-BrownserveRepository -Components PowerShellModule, MkDocs -ComponentOptions @{ PowerShellModule = @{ ModuleInfo = $ModuleInfo } }
    Initialises the current directory as a PowerShell module repository with MkDocs documentation.
#>
function Initialize-BrownserveRepository
{
    [CmdletBinding()]
    param
    (
        # The path to the repository
        [Parameter(Mandatory = $false, Position = 0)]
        [string]
        $RepositoryPath = (Get-Location),

        # The components that should be present in this repository, 'Core' is always included automatically
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Components,

        # Options for the requested components, keyed by component name
        [Parameter(Mandatory = $false)]
        [hashtable]
        $ComponentOptions = @{},

        # The GitHub repository name, if different from the local directory name.
        # Defaults to the leaf name of RepositoryPath if not provided.
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName,

        # The owner of the repository (used for licensing and other metadata)
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK',

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
        try
        {
            $RepositoryState = Compare-BrownserveRepository `
                -RepositoryPath $RepositoryPath `
                -Components $Components `
                -ComponentOptions $ComponentOptions `
                -Force:$Force `
                -Owner $Owner `
                -RepoName $RepoName `
                -ErrorAction 'Stop'
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
            if (($RepositoryState.ChangedFiles.Count -gt 0) -and !$Force)
            {
                throw "Repository has already been initialized and contains changes that would be overwritten.`nUse the 'Update-BrownserveRepository' cmdlet to update the repository or pass the '-Force' switch to re-initialize the repository."
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
            $TempBranchName = 'brownserve_repo_init'
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
                Write-Verbose "Creating directory '$($Directory.Path)'"
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
            Write-Verbose 'Repository is already initialized and up to date'
        }
    }
    end
    {
    }
}
