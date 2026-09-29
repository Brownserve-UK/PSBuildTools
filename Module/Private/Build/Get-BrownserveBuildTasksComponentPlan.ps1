<#
.SYNOPSIS
    Works out which resolved components contribute a 'BuildTasks' task file, and what each one needs from
    the generated 'build.ps1'/'build_tasks.ps1'.
.DESCRIPTION
    Shared by 'New-BrownserveBuildScript' and 'New-BrownserveBuildTasksScript' so both generators agree on
    which components are active, which of their task file parameters are runtime-forwarded (as opposed to
    baked as literals from component options, or left to the task file's own default), and the union of
    public targets and publish values across the whole repository.
#>
function Get-BrownserveBuildTasksComponentPlan
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
        $ComponentDefinitions
    )
    process
    {
        $ReleaseLifecycleParameterNames = @('ReleaseType', 'BranchName', 'DefaultBranch', 'PublishTo', 'GitHubRepoOwner', 'GitHubRepoName', 'GitHubStageReleaseToken', 'GitHubReleaseToken')

        $TaskComponents = [System.Collections.Generic.List[object]]::new()
        foreach ($Component in $ResolvedComponents)
        {
            $Definition = $ComponentDefinitions[$Component.Name]
            if (!$Definition.Data.BuildTasks)
            {
                continue
            }
            $BuildTasksData = $Definition.Data.BuildTasks
            $LiteralNames = @($BuildTasksData.OptionParameterMap.Values)
            if ($BuildTasksData.ModuleInfoMap)
            {
                $LiteralNames += @($BuildTasksData.ModuleInfoMap.Keys)
            }
            $SkipNames = @($BuildTasksData.SkipParameters)
            $RuntimeNames = @($BuildTasksData.Parameters | Where-Object {
                        $_ -notin $ReleaseLifecycleParameterNames -and $_ -notin $LiteralNames -and $_ -notin $SkipNames
                    })
            $PublishValues = @($BuildTasksData.PublishValues)
            if ($BuildTasksData.PublishValuesOption)
            {
                $OptionName = $BuildTasksData.PublishValuesOption
                $Chosen = @($Component.Options[$OptionName] | Where-Object { $_ })
                $Unknown = @($Chosen | Where-Object { $_ -notin $PublishValues })
                if ($Chosen.Count -eq 0 -or $Unknown.Count -gt 0)
                {
                    $Detail = if ($Chosen.Count -eq 0) { 'it can not be empty' } else { "'$($Unknown -join "', '")' is not allowed" }
                    throw "The '$OptionName' option of the $($Component.Name) component is invalid: $Detail. Allowed values are $(($PublishValues | ForEach-Object { "'$_'" }) -join ', ')."
                }
                $PublishValues = @($PublishValues | Where-Object { $_ -in $Chosen })
            }
            $TaskComponents.Add([pscustomobject]@{
                    Name                  = $Component.Name
                    Options               = $Component.Options
                    BuildTasks            = $BuildTasksData
                    PublishValues         = $PublishValues
                    RuntimeParameterNames = $RuntimeNames
                })
        }

        $ReleaseLifecycleComponent = $TaskComponents | Where-Object { $_.Name -eq 'ReleaseLifecycle' } | Select-Object -First 1
        $OtherComponents = @($TaskComponents | Where-Object { $_.Name -ne 'ReleaseLifecycle' })
        $IsPowerShellModule = [bool]($TaskComponents.Name -contains 'PowerShellModule')

        $PublishToValues = @()
        $PublicTargets = @()
        foreach ($TaskComponent in $TaskComponents)
        {
            $PublishToValues += $TaskComponent.PublishValues
            $PublicTargets += $TaskComponent.BuildTasks.PublicTargets
        }
        $PublishToValues = @($PublishToValues | Select-Object -Unique)
        $PublicTargets = @($PublicTargets | Select-Object -Unique)

        $NuGetPackageComponent = $TaskComponents | Where-Object { $_.Name -eq 'NuGetPackage' } | Select-Object -First 1
        $UseWorkingCopyTasks = $false
        if ($NuGetPackageComponent -and $NuGetPackageComponent.Options.UseWorkingCopy)
        {
            $UseWorkingCopyTasks = $true
        }

        $MetaTargetAnchors = [ordered]@{
            'Build'             = @('Build')
            'BuildAndTest'      = @('Build', 'Test')
            'BuildTestAndCheck' = @('Build', 'Test', 'Check')
            'StageRelease'      = @('Stage')
            'DryRun'            = @('Build', 'Test', 'Package')
            'Release'           = @('Build', 'Test', 'Package', 'Publish')
        }
        $SharedTargetAnchors = [ordered]@{}
        foreach ($Key in $MetaTargetAnchors.Keys)
        {
            $SharedTargetAnchors[$Key] = $MetaTargetAnchors[$Key]
        }
        if ($IsPowerShellModule)
        {
            $SharedTargetAnchors['BuildAndImport'] = @('Build')
            $SharedTargetAnchors['BuildWithDocs'] = @('Build')
        }

        return [pscustomobject]@{
            ReleaseLifecycleParameterNames = $ReleaseLifecycleParameterNames
            TaskComponents                 = $TaskComponents
            ReleaseLifecycleComponent      = $ReleaseLifecycleComponent
            OtherComponents                = $OtherComponents
            IsPowerShellModule             = $IsPowerShellModule
            PublishToValues                = $PublishToValues
            PublicTargets                  = $PublicTargets
            UseWorkingCopyTasks            = $UseWorkingCopyTasks
            MetaTargetAnchors              = $MetaTargetAnchors
            SharedTargetAnchors            = $SharedTargetAnchors
        }
    }
}
