<#
.SYNOPSIS
    Maps a job's target matrix onto the GitHub Actions runners it runs on.
.DESCRIPTION
    A job without a target matrix runs on the default runner. Otherwise each target is looked up in the owning
    component's 'GitHubActions.Runners' map and the unique runners are returned in target order. A target with no
    runner throws.
#>
function Get-BrownserveGitHubRunner
{
    [CmdletBinding()]
    param
    (
        # The targets the job runs for, empty when the job has no target matrix
        [Parameter(Mandatory = $false)]
        [string[]]
        $Targets = @(),

        # The name of the component that owns the targets
        [Parameter(Mandatory = $false)]
        [string]
        $Component,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions
    )
    process
    {
        $DefaultRunner = $ComponentDefinitions['Core'].Data.GitHubActions.DefaultRunner
        if ($Targets.Count -eq 0)
        {
            return @($DefaultRunner)
        }
        $RunnerMap = $ComponentDefinitions[$Component].Data.GitHubActions.Runners
        $Runners = @()
        foreach ($Target in $Targets)
        {
            if (!$RunnerMap -or !$RunnerMap.ContainsKey($Target))
            {
                throw "The target '$Target' has no GitHub Actions runner. Add it to 'GitHubActions.Runners' in 'Module/Private/Components/$Component/component.psd1'."
            }
            $Runners += $RunnerMap[$Target]
        }
        return @($Runners | Select-Object -Unique)
    }
}
