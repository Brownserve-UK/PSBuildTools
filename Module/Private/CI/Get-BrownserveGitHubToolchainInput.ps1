<#
.SYNOPSIS
    Works out which toolchain inputs a reusable workflow call needs to set.
.DESCRIPTION
    Takes the toolchain requirements that apply to a job and maps each tool onto an input of the reusable workflow
    being called. Requirements whose platform never applies to the job's runners are ignored. A tool the runners
    already provide (e.g. docker on 'ubuntu-latest') needs no input. Anything else the workflow has no input for
    throws, naming the tool, the component and the workflow.
    The inputs come back in the order the workflow declares them.
#>
function Get-BrownserveGitHubToolchainInput
{
    [CmdletBinding()]
    param
    (
        # The toolchain requirements that apply to the job
        [Parameter(Mandatory = $false)]
        [psobject[]]
        $Requirements = @(),

        # The runners the job runs on
        [Parameter(Mandatory = $true)]
        [string[]]
        $Runners,

        # The reusable workflow being called, as named in the 'GitHubActions.Workflows' data
        [Parameter(Mandatory = $true)]
        [string]
        $Workflow,

        # Every known component definition, keyed by name
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ComponentDefinitions
    )
    process
    {
        $GitHubData = $ComponentDefinitions['Core'].Data.GitHubActions
        $WorkflowData = $GitHubData.Workflows[$Workflow]
        $Inputs = @()
        foreach ($Requirement in $Requirements)
        {
            $ApplicableRunners = @($Runners | Where-Object {
                    $RunnerIsWindows = $_ -like 'windows*'
                    switch ($Requirement.Platform)
                    {
                        'Windows' { $RunnerIsWindows }
                        'NonWindows' { !$RunnerIsWindows }
                        default { $true }
                    }
                })
            if ($ApplicableRunners.Count -eq 0)
            {
                continue
            }
            if ($ApplicableRunners.Count -ne $Runners.Count)
            {
                throw "The '$($Requirement.Tools -join ', ')' toolchain required by $($Requirement.Component) only applies to some of the runners ($($Runners -join ', ')), but the '$($WorkflowData.File)' workflow can't set it per runner."
            }
            foreach ($Tool in $Requirement.Tools)
            {
                if ($WorkflowData.RunnerProvidedTools -contains $Tool)
                {
                    continue
                }
                $Preinstalled = $GitHubData.PreinstalledTools[$Tool]
                if ($Preinstalled)
                {
                    $UnsupportedRunners = @($Runners | Where-Object { $_ -notin $Preinstalled })
                    if ($UnsupportedRunners.Count -gt 0)
                    {
                        throw "The '$Tool' toolchain required by $($Requirement.Component) is only available on $($Preinstalled -join ', ') but the '$($WorkflowData.File)' workflow also runs on $($UnsupportedRunners -join ', ')."
                    }
                    continue
                }
                $InputName = $GitHubData.ToolchainInputs[$Tool]
                if (!$InputName -or $WorkflowData.ToolchainInputs -notcontains $InputName)
                {
                    throw "The '$Tool' toolchain required by $($Requirement.Component) can't be provided by the '$($WorkflowData.File)' workflow, which has no input for it."
                }
                $Inputs += $InputName
            }
        }
        return @($WorkflowData.ToolchainInputs | Where-Object { $_ -in $Inputs })
    }
}
