<#
.SYNOPSIS
    Builds the pinned 'uses:' value for one of the reusable workflows in Brownserve-UK/actions.
.DESCRIPTION
    Every reference is pinned to the commit SHA held in the 'Core' component's 'GitHubActions' data, followed by
    a comment with the matching release version, e.g.
    'Brownserve-UK/actions/.github/workflows/brownserve-pr-build.yaml@<sha> # v0.1.0'.
#>
function Get-BrownserveGitHubWorkflowReference
{
    [CmdletBinding()]
    param
    (
        # The reusable workflow, as named in the 'GitHubActions.Workflows' data
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
        $WorkflowFile = $GitHubData.Workflows[$Workflow].File
        return "$($GitHubData.ActionsRepository)/.github/workflows/$WorkflowFile@$($GitHubData.ActionsCommit) # $($GitHubData.ActionsVersion)"
    }
}
