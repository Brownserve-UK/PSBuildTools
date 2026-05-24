function New-BrownservePowerShellModuleBuild
{
    [CmdletBinding()]
    param
    (
        # The CI/CD provider
        [Parameter(Mandatory = $true)]
        [BrownserveCICD]
        $CICDProvider,

        # The module information
        [Parameter(Mandatory = $true)]
        [BrownservePowerShellModule]
        $ModuleInfo,

        # The path to where the repo is that contains the module
        [Parameter(Mandatory = $true)]
        [string]
        $RepoPath,

        # The name of the repository this module lives in
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName
    )
    begin
    {
        try
        {
            Assert-Directory $RepoPath
            $RepoPath = $RepoPath | Convert-Path
        }
        catch
        {
            throw "$($_.Exception.Message)"
        }
        if (!$RepoName)
        {
            Write-Verbose 'No repo name, using directory name'
            $RepoName = Split-Path $RepoPath -Leaf
        }
        if (!$RepoName)
        {
            throw 'Cannot determine RepoName automatically.'
        }
    }
    process
    {
        switch ($CICDProvider)
        {
            'GitHubActions'
            {
                $GitHubDirectory = Join-Path $RepoPath '.github'
                $WorkflowDirectory = Join-Path $GitHubDirectory 'workflows'
                $BuildsWorkflowPath = Join-Path $WorkflowDirectory 'builds.yaml'
                $StageReleaseWorkflowPath = Join-Path $WorkflowDirectory 'stage-release.yaml'
                $ReleaseWorkflowPath = Join-Path $WorkflowDirectory 'release.yaml'

                @($BuildsWorkflowPath, $StageReleaseWorkflowPath, $ReleaseWorkflowPath) | Assert-PathDoesNotExist

                try
                {
                    $BuildsWorkflowContent = New-BrownserveGitHubBuildsWorkflow -ModuleName $ModuleInfo.Name
                    $StageReleaseWorkflowContent = New-BrownserveGitHubStageReleaseWorkflow -ModuleName $ModuleInfo.Name
                    $ReleaseWorkflowContent = New-BrownserveGitHubReleaseWorkflow -ModuleName $ModuleInfo.Name
                }
                catch
                {
                    throw "Failed to generate GitHub Actions workflow content.`n$($_.Exception.Message)"
                }

                try
                {
                    if (!(Test-Path $GitHubDirectory))
                    {
                        New-Item $GitHubDirectory -ItemType Directory -ErrorAction 'Stop' | Out-Null
                    }
                    if (!(Test-Path $WorkflowDirectory))
                    {
                        New-Item $WorkflowDirectory -ItemType Directory -ErrorAction 'Stop' | Out-Null
                    }
                    New-Item $BuildsWorkflowPath -ItemType File -Value $BuildsWorkflowContent -ErrorAction 'Stop' | Out-Null
                    New-Item $StageReleaseWorkflowPath -ItemType File -Value $StageReleaseWorkflowContent -ErrorAction 'Stop' | Out-Null
                    New-Item $ReleaseWorkflowPath -ItemType File -Value $ReleaseWorkflowContent -ErrorAction 'Stop' | Out-Null
                }
                catch
                {
                    throw "Failed to write workflows to disk.`n$($_.Exception.Message)"
                }
            }
            Default
            {
                throw "Unsupported CI/CD provider '$CICDProvider'"
            }
        }
    }
    end
    {
    }
}
