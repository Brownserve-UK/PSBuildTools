<#
.SYNOPSIS
    Generates the seeded content for a repository's 'custom.tasks.ps1' file.
.DESCRIPTION
    'custom.tasks.ps1' is created once with this content and then left under repository ownership, so
    repository-specific Invoke-Build tasks can be added without being overwritten by future updates.
#>
function New-BrownserveCustomTasksScript
{
    [CmdletBinding()]
    param
    (
    )
    process
    {
        return @'
<#
.SYNOPSIS
    Repository-specific build tasks for this repo.
.DESCRIPTION
    Tasks that are specific to this repository and don't belong in a shared Brownserve.PSBuildTasks task
    file go here, attached to the anchors defined in ReleaseLifecycle.tasks.ps1 (Build, Test, Check, Package,
    Stage, Publish) using Invoke-Build's -Before/-After parameters.
#>
'@
    }
}
