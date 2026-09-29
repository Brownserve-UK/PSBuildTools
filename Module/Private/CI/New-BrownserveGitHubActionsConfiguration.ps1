<#
.SYNOPSIS
    Turns a provider-neutral CI plan into GitHub Actions workflow files.
.DESCRIPTION
    Every workflow is a thin caller of a reusable workflow in Brownserve-UK/actions, pinned by commit SHA. This is
    where the neutral plan meets GitHub: target matrices become runners, permissions become token scopes,
    secrets become repository secret mappings and toolchains become the reusable workflow's inputs. The values
    needed for that (pins, runners, scopes, secret names) live in the components' 'GitHubActions' data.
    The pull request workflow keeps a local 'merge-checks' job that needs every CI job, so the required status
    check name stays stable however many jobs a repository has.
#>
function New-BrownserveGitHubActionsConfiguration
{
    [CmdletBinding()]
    param
    (
        # The provider-neutral plan from 'Get-BrownserveCIPlan'
        [Parameter(Mandatory = $true)]
        [psobject]
        $Plan,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions
    )
    process
    {
        $Files = @()
        $RepoName = ConvertTo-BrownserveYamlSingleQuoted $Plan.RepoName

        if ($Plan.IncludeWorkflows)
        {
            $Lines = @('---', 'name: builds', 'on:', '  pull_request:', '    branches:', '      - main', '', 'permissions: {}', '', 'jobs:')
            foreach ($Job in $Plan.PullRequest.Jobs)
            {
                $Runners = @(Get-BrownserveGitHubRunner -Targets $Job.MatrixTargets -Component $Job.Component -ComponentDefinitions $ComponentDefinitions)
                $ToolchainInputs = @(Get-BrownserveGitHubToolchainInput -Requirements $Job.Toolchains -Runners $Runners -Workflow 'PullRequestBuild' -ComponentDefinitions $ComponentDefinitions)
                $Pattern = "^($($Job.ChangePatterns -join '|'))"
                $Lines += "  $($Job.Name):"
                $Lines += "    uses: $(Get-BrownserveGitHubWorkflowReference -Workflow 'PullRequestBuild' -ComponentDefinitions $ComponentDefinitions)"
                $Lines += Format-BrownserveGitHubPermission -Permissions $Plan.PullRequest.Permissions -ComponentDefinitions $ComponentDefinitions
                $Lines += '    with:'
                $Lines += "      repo-name: $RepoName"
                $Lines += "      change-pattern: $(ConvertTo-BrownserveYamlSingleQuoted $Pattern)"
                $Lines += "      build-task: $($Job.BuildTask)"
                $Lines += "      os-matrix: $(ConvertTo-BrownserveYamlSingleQuoted (ConvertTo-Json -InputObject $Runners -Compress))"
                foreach ($ToolchainInput in $ToolchainInputs)
                {
                    $Lines += "      ${ToolchainInput}: true"
                }
                $Lines += ''
            }
            $JobNames = @($Plan.PullRequest.Jobs.Name)
            $Lines += '  # Gate job: always runs and reports the single status check name that branch protection requires.'
            $Lines += '  # Skipped and cancelled jobs fail it, path-filter skips are reported as successes by the called workflow.'
            $Lines += '  merge-checks:'
            $Lines += '    needs:'
            $Lines += $JobNames | ForEach-Object { "      - $_" }
            $Lines += '    if: always()'
            $Lines += '    runs-on: ubuntu-latest'
            $Lines += '    timeout-minutes: 5'
            $Lines += '    permissions: {}'
            $Lines += '    steps:'
            $Lines += '      - name: evaluate-build-results'
            $Lines += '        env:'
            foreach ($JobName in $JobNames)
            {
                $EnvName = ($JobName -replace '-', '_').ToUpper() + '_RESULT'
                $Lines += "          ${EnvName}: `${{ needs.$JobName.result }}"
            }
            $Lines += '        run: |'
            $Lines += '          FAILED=0'
            foreach ($JobName in $JobNames)
            {
                $EnvName = ($JobName -replace '-', '_').ToUpper() + '_RESULT'
                $Lines += "          if [ `"`$$EnvName`" != `"success`" ]; then"
                $Lines += "            echo `"$JobName did not succeed (result: `$$EnvName)`""
                $Lines += '            FAILED=1'
                $Lines += '          fi'
            }
            $Lines += '          if [ "$FAILED" -ne 0 ]; then'
            $Lines += '            exit 1'
            $Lines += '          fi'
            $Lines += '          echo "All required jobs succeeded"'
            $Files += [pscustomobject]@{ Path = '.github/workflows/builds.yaml'; Content = ($Lines -join "`n") + "`n" }

            $Lines = @(
                '---', 'name: stage-release', 'on:', '  workflow_dispatch:', '    inputs:', '      release_type:',
                "        description: 'The type of release to perform'", '        required: true', "        default: 'minor'",
                '        type: choice', '        options:', '          - major', '          - minor', '          - patch',
                '', 'permissions: {}', '', 'jobs:', '  stage-release:'
            )
            $StageInputs = @(Get-BrownserveGitHubToolchainInput -Requirements $Plan.StageRelease.Toolchains -Runners @($ComponentDefinitions['Core'].Data.GitHubActions.DefaultRunner) -Workflow 'StageRelease' -ComponentDefinitions $ComponentDefinitions)
            $Lines += "    uses: $(Get-BrownserveGitHubWorkflowReference -Workflow 'StageRelease' -ComponentDefinitions $ComponentDefinitions)"
            $Lines += Format-BrownserveGitHubPermission -Permissions $Plan.StageRelease.Permissions -ComponentDefinitions $ComponentDefinitions
            $Lines += '    with:'
            $Lines += "      repo-name: $RepoName"
            $Lines += '      release-type: ${{ inputs.release_type }}'
            foreach ($StageInput in $StageInputs)
            {
                $Lines += "      ${StageInput}: true"
            }
            $Lines += Format-BrownserveGitHubSecret -Secrets $Plan.StageRelease.Secrets -ComponentDefinitions $ComponentDefinitions
            $Files += [pscustomobject]@{ Path = '.github/workflows/stage-release.yaml'; Content = ($Lines -join "`n") + "`n" }

            $PublishDefault = ($Plan.Release.PublishTo | ForEach-Object { "`"$_`"" }) -join ', '
            $Lines = @(
                '---', 'name: release', 'on:', '  workflow_dispatch:', '    inputs:', '      publish_to:',
                "        description: 'Where to publish the release to'", '        required: true',
                "        default: $(ConvertTo-BrownserveYamlSingleQuoted $PublishDefault)", '        type: string',
                '', 'permissions: {}', '', 'jobs:', '  release:'
            )
            $ReleaseInputs = @(Get-BrownserveGitHubToolchainInput -Requirements $Plan.Release.Toolchains -Runners @($ComponentDefinitions['Core'].Data.GitHubActions.DefaultRunner) -Workflow 'Release' -ComponentDefinitions $ComponentDefinitions)
            $Lines += "    uses: $(Get-BrownserveGitHubWorkflowReference -Workflow 'Release' -ComponentDefinitions $ComponentDefinitions)"
            $Lines += Format-BrownserveGitHubPermission -Permissions $Plan.Release.Permissions -ComponentDefinitions $ComponentDefinitions
            $Lines += '    with:'
            $Lines += "      repo-name: $RepoName"
            $Lines += '      publish-to: ${{ inputs.publish_to }}'
            if ($Plan.Release.PackageMatrix)
            {
                $Includes = @()
                foreach ($Target in $Plan.Release.PackageMatrix.Targets)
                {
                    $Runner = @(Get-BrownserveGitHubRunner -Targets @($Target) -Component $Plan.Release.PackageMatrix.Component -ComponentDefinitions $ComponentDefinitions)[0]
                    $Includes += [ordered]@{ os = $Runner; target = $Target }
                }
                $Lines += "      package-matrix: $(ConvertTo-BrownserveYamlSingleQuoted (ConvertTo-Json -InputObject $Includes -Compress))"
                $Lines += "      package-build-task: $($Plan.Release.PackageMatrix.BuildTask)"
            }
            foreach ($ReleaseInput in $ReleaseInputs)
            {
                $Lines += "      ${ReleaseInput}: true"
            }
            $Lines += Format-BrownserveGitHubSecret -Secrets $Plan.Release.Secrets -ComponentDefinitions $ComponentDefinitions
            if ($Plan.DeployDocs)
            {
                $Lines += ''
                $Lines += '  deploy-docs:'
                $Lines += '    needs: release'
                $Lines += "    uses: $(Get-BrownserveGitHubWorkflowReference -Workflow 'DeployDocs' -ComponentDefinitions $ComponentDefinitions)"
                $Lines += Format-BrownserveGitHubPermission -Permissions $Plan.DeployDocs.Permissions -ComponentDefinitions $ComponentDefinitions
                $Lines += '    with:'
                $Lines += "      engine: $($Plan.DeployDocs.Engine)"
                if ($Plan.DeployDocs.Path)
                {
                    $Lines += "      docs-path: $($Plan.DeployDocs.Path)"
                }
            }
            $Files += [pscustomobject]@{ Path = '.github/workflows/release.yaml'; Content = ($Lines -join "`n") + "`n" }
        }

        if ($Plan.IncludeLabelPR)
        {
            $Lines = @(
                '---', 'name: label-pr', 'on:', '  pull_request_target:', '    types:', '      - opened', '      - edited',
                '      - reopened', '      - synchronize', '      - labeled', '      - unlabeled', '    branches:', '      - main',
                '', 'permissions: {}', '', 'jobs:', '  label-pr:'
            )
            $Lines += "    uses: $(Get-BrownserveGitHubWorkflowReference -Workflow 'LabelPullRequest' -ComponentDefinitions $ComponentDefinitions)"
            $Lines += Format-BrownserveGitHubPermission -Permissions $Plan.LabelPullRequest.Permissions -ComponentDefinitions $ComponentDefinitions
            $Files += [pscustomobject]@{ Path = '.github/workflows/label-pr.yaml'; Content = ($Lines -join "`n") + "`n" }
        }

        return $Files
    }
}
