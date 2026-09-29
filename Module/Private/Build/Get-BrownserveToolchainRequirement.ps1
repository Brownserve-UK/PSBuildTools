<#
.SYNOPSIS
    Works out every toolchain requirement declared by the resolved components and the targets each applies to.
.DESCRIPTION
    Each component's 'BuildTasks.Toolchains' entry names the tools it needs and the anchors (Build, Test,
    Package, ...) whose contributions need them. This maps those anchors onto the repository's shared targets
    (e.g. 'BuildTestAndCheck') and the component's own public targets (e.g. 'RustBinary.Check').
    Shared by 'New-BrownserveBuildScript' (the 'build.ps1' toolchain check) and the CI generators so both agree
    on what a given target needs.
#>
function Get-BrownserveToolchainRequirement
{
    [CmdletBinding()]
    param
    (
        # The plan returned by 'Get-BrownserveBuildTasksComponentPlan'
        [Parameter(Mandatory = $true)]
        [psobject]
        $Plan
    )
    process
    {
        foreach ($TaskComponent in $Plan.TaskComponents)
        {
            foreach ($Requirement in $TaskComponent.BuildTasks.Toolchains)
            {
                $ApplicableTargets = [System.Collections.Generic.List[string]]::new()
                foreach ($SharedTarget in $Plan.SharedTargetAnchors.Keys)
                {
                    $SharedAnchors = $Plan.SharedTargetAnchors[$SharedTarget]
                    if ($SharedAnchors | Where-Object { $Requirement.Anchors -contains $_ })
                    {
                        $ApplicableTargets.Add($SharedTarget)
                    }
                }
                if ($TaskComponent.BuildTasks.PublicTargetAnchors)
                {
                    foreach ($OwnTarget in ($TaskComponent.BuildTasks.PublicTargetAnchors.Keys | Sort-Object))
                    {
                        $OwnAnchors = $TaskComponent.BuildTasks.PublicTargetAnchors[$OwnTarget]
                        if ($OwnAnchors | Where-Object { $Requirement.Anchors -contains $_ })
                        {
                            $ApplicableTargets.Add($OwnTarget)
                        }
                    }
                }
                $ApplicableTargets = @($ApplicableTargets | Select-Object -Unique)
                if ($ApplicableTargets.Count -eq 0)
                {
                    continue
                }
                [pscustomobject]@{
                    Component          = $TaskComponent.Name
                    Tools              = @($Requirement.Tools)
                    Targets            = $ApplicableTargets
                    Platform           = $Requirement.Platform
                    CollectorParameter = $TaskComponent.BuildTasks.CollectorParameter
                }
            }
        }
    }
}
