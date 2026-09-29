<#
.SYNOPSIS
    Builds the provider-neutral CI plan for a repository's resolved components.
.DESCRIPTION
    Describes what CI has to do without saying how any one provider does it: which jobs run for a pull request
    (a build task, the changed-file patterns that trigger it, an optional target matrix and the toolchains it
    needs), what staging and releasing need, which secrets and permissions each pipeline requires and whether
    documentation is deployed.
    If every component that adds build or test work has a public '.Check' target then each gets its own job. If
    none does then a single 'BuildTestAndCheck' job covers the whole repository. Any other mix is refused.
    The plan is turned into provider specific files by a provider function such as
    'New-BrownserveGitHubActionsConfiguration'.
#>
function Get-BrownserveCIPlan
{
    [CmdletBinding()]
    param
    (
        # The resolved components for this repository
        [Parameter(Mandatory = $true)]
        [BrownserveResolvedComponent[]]
        $ResolvedComponents,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions,

        # The name of the repository
        [Parameter(Mandatory = $true)]
        [string]
        $RepoName,

        # The account that owns the repository
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK'
    )
    process
    {
        $BuildPlan = Get-BrownserveBuildTasksComponentPlan -ResolvedComponents $ResolvedComponents -ComponentDefinitions $ComponentDefinitions
        $Requirements = @(Get-BrownserveToolchainRequirement -Plan $BuildPlan)
        $CoreCI = $ComponentDefinitions['Core'].Data.CI
        $CommonPatterns = @($CoreCI.ChangePatterns)

        $ResolvedByName = @{}
        $ResolvedComponents | ForEach-Object { $ResolvedByName[$_.Name] = $_ }

        $WorkComponents = @()
        foreach ($TaskComponent in $BuildPlan.OtherComponents)
        {
            $Anchors = @()
            foreach ($TargetAnchors in $TaskComponent.BuildTasks.PublicTargetAnchors.Values)
            {
                $Anchors += $TargetAnchors
            }
            foreach ($Toolchain in $TaskComponent.BuildTasks.Toolchains)
            {
                $Anchors += $Toolchain.Anchors
            }
            if ($Anchors | Where-Object { $_ -in @('Build', 'Test') })
            {
                $WorkComponents += $TaskComponent
            }
        }
        $CheckComponents = @($WorkComponents | Where-Object { $_.BuildTasks.PublicTargets -match '\.Check$' })
        $UnscopedComponents = @($WorkComponents | Where-Object { $_.Name -notin $CheckComponents.Name })
        if ($CheckComponents.Count -gt 0 -and $UnscopedComponents.Count -gt 0)
        {
            throw "Can't choose CI jobs for a repository that mixes components with a '.Check' target ($($CheckComponents.Name -join ', ')) and components that add build or test work without one ($($UnscopedComponents.Name -join ', '))."
        }

        $Jobs = @()
        if ($CheckComponents.Count -gt 0)
        {
            foreach ($CheckComponent in $CheckComponents)
            {
                $Definition = $ComponentDefinitions[$CheckComponent.Name]
                $Target = @($CheckComponent.BuildTasks.PublicTargets | Where-Object { $_ -match '\.Check$' })[0]
                $ComponentPatterns = @(Get-BrownserveCIChangePattern -Component $ResolvedByName[$CheckComponent.Name] -Definition $Definition)
                $MatrixTargets = @()
                if ($Definition.Data.CI.TargetOption)
                {
                    $MatrixTargets = @($CheckComponent.Options[$Definition.Data.CI.TargetOption])
                }
                $Jobs += [pscustomobject]@{
                    Name           = ($CheckComponent.Name -creplace '(?<=[a-z0-9])(?=[A-Z])', '-').ToLower()
                    Component      = $CheckComponent.Name
                    BuildTask      = $Target
                    ChangePatterns = @($ComponentPatterns + $CommonPatterns | Select-Object -Unique)
                    MatrixTargets  = $MatrixTargets
                    Toolchains     = @($Requirements | Where-Object { $_.Targets -contains $Target })
                }
            }
        }
        else
        {
            $AllPatterns = @()
            foreach ($Component in ($ResolvedComponents | Where-Object { $_.Name -ne 'Core' }))
            {
                $AllPatterns += Get-BrownserveCIChangePattern -Component $Component -Definition $ComponentDefinitions[$Component.Name]
            }
            $Jobs += [pscustomobject]@{
                Name           = 'build'
                Component      = $null
                BuildTask      = 'BuildTestAndCheck'
                ChangePatterns = @($AllPatterns + $CommonPatterns | Select-Object -Unique)
                MatrixTargets  = @()
                Toolchains     = @($Requirements | Where-Object { $_.Targets -contains 'BuildTestAndCheck' })
            }
        }

        $PackageMatrix = $null
        $PackageComponent = $BuildPlan.OtherComponents | Where-Object { $ComponentDefinitions[$_.Name].Data.CI.PackageTarget } | Select-Object -First 1
        if ($PackageComponent)
        {
            $PackageCI = $ComponentDefinitions[$PackageComponent.Name].Data.CI
            $PackageMatrix = [pscustomobject]@{
                Component = $PackageComponent.Name
                BuildTask = $PackageCI.PackageTarget
                Targets   = @($PackageComponent.Options[$PackageCI.TargetOption])
            }
        }
        $CollectorComponent = if ($PackageMatrix -and $ComponentDefinitions[$PackageMatrix.Component].Data.BuildTasks.CollectorParameter) { $PackageMatrix.Component } else { $null }

        $ReleaseSecrets = @($CoreCI.Pipelines.Release.Secrets)
        $ReleasePermissions = @($CoreCI.Pipelines.Release.Permissions)
        foreach ($TaskComponent in $BuildPlan.OtherComponents)
        {
            $ComponentCI = $ComponentDefinitions[$TaskComponent.Name].Data.CI
            foreach ($PublishValue in $TaskComponent.PublishValues)
            {
                if ($ComponentCI.PublishSecrets -and $ComponentCI.PublishSecrets.ContainsKey($PublishValue))
                {
                    $ReleaseSecrets += $ComponentCI.PublishSecrets[$PublishValue]
                }
                if ($ComponentCI.PublishPermissions -and $ComponentCI.PublishPermissions.ContainsKey($PublishValue))
                {
                    $ReleasePermissions += $ComponentCI.PublishPermissions[$PublishValue]
                }
            }
        }

        $Docs = $null
        foreach ($Component in $ResolvedComponents)
        {
            $DeployDocs = $ComponentDefinitions[$Component.Name].Data.CI.DeployDocs
            if ($DeployDocs -and !$Docs)
            {
                $Docs = [pscustomobject]@{
                    Component   = $Component.Name
                    Engine      = $DeployDocs.Engine
                    Path        = $DeployDocs.Path
                    Permissions = @($DeployDocs.Permissions)
                }
            }
        }

        $ReleaseLifecycleData = $null
        if ($ResolvedByName.ContainsKey('ReleaseLifecycle'))
        {
            $ReleaseLifecycleData = $ComponentDefinitions['ReleaseLifecycle'].Data
        }

        return [pscustomobject]@{
            RepoName         = $RepoName
            Owner            = $Owner
            IncludeWorkflows = [bool]($ReleaseLifecycleData -and $ReleaseLifecycleData.IncludeWorkflows)
            IncludeLabelPR   = [bool]($ReleaseLifecycleData -and $ReleaseLifecycleData.IncludeLabelPR)
            PullRequest      = [pscustomobject]@{
                Jobs        = $Jobs
                Permissions = @($CoreCI.Pipelines.PullRequestBuild.Permissions)
            }
            StageRelease     = [pscustomobject]@{
                BuildTask   = 'StageRelease'
                Toolchains  = @($Requirements | Where-Object { $_.Targets -contains 'StageRelease' })
                Permissions = @($CoreCI.Pipelines.StageRelease.Permissions)
                Secrets     = @($CoreCI.Pipelines.StageRelease.Secrets)
            }
            Release          = [pscustomobject]@{
                BuildTask     = 'Release'
                Toolchains    = @($Requirements | Where-Object { $_.Targets -contains 'Release' -and $_.Component -ne $CollectorComponent })
                Permissions   = @($ReleasePermissions | Select-Object -Unique)
                Secrets       = @($ReleaseSecrets | Select-Object -Unique)
                PublishTo     = @($BuildPlan.PublishToValues | Where-Object { $_ -ne 'CustomNugetFeeds' })
                PackageMatrix = $PackageMatrix
            }
            LabelPullRequest = [pscustomobject]@{
                Permissions = @($CoreCI.Pipelines.LabelPullRequest.Permissions)
            }
            DeployDocs       = $Docs
        }
    }
}
