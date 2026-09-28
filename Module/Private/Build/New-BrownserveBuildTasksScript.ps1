<#
.SYNOPSIS
    Generates the content of a thin 'build_tasks.ps1' for a repository's resolved components.
.DESCRIPTION
    Composes a param() block from 'ReleaseLifecycle.tasks.ps1' (always dot-sourced first) plus whichever
    other component task files are needed, then dot-sources the pinned 'Brownserve.PSBuildTasks' task files
    (or the repository's own working copy of 'tasks/' when the 'NuGetPackage' component has
    'UseWorkingCopy' set) with only the parameters each file declares, followed by the seeded
    'custom.tasks.ps1'. It never emits meta tasks or task bodies; those live entirely in the task files.
    Each task file validates its own 'PublishTo' values (e.g. RustBinary only accepts 'GitHub'), so the
    repository-wide 'PublishTo' is filtered down to each component's own 'PublishValues' before it's
    forwarded, and only forwarded at all when that filtered set isn't empty.
#>
function New-BrownserveBuildTasksScript
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

        # The PowerShell module information, if the 'PowerShellModule' component is present
        [Parameter(Mandatory = $false)]
        [psobject]
        $ModuleInfo
    )
    process
    {
        function ConvertTo-BrownserveBuildScriptLiteral
        {
            param ($Value)
            if ($null -eq $Value)
            {
                return '$null'
            }
            if ($Value -is [bool])
            {
                return "`$$Value"
            }
            if ($Value -is [array])
            {
                $Items = @($Value | ForEach-Object { "'$_'" }) -join ', '
                return "@($Items)"
            }
            return "'$Value'"
        }

        function Format-BrownserveAlignedHashtable
        {
            param ($VariableName, $Pairs)
            $Lines = [System.Collections.Generic.List[string]]::new()
            $Lines.Add("`$$VariableName = @{")
            if ($Pairs.Count -gt 0)
            {
                $MaxKeyLength = ($Pairs.Keys | Measure-Object -Property Length -Maximum).Maximum
                foreach ($Key in $Pairs.Keys)
                {
                    $Padding = ' ' * ($MaxKeyLength - $Key.Length)
                    $Lines.Add("    $Key$Padding = $($Pairs[$Key])")
                }
            }
            $Lines.Add('}')
            return $Lines
        }

        $CommonDescriptions = @{
            ReleaseType             = 'The type of changes that this version of the release contains, used to determine the version number'
            BranchName              = 'The branch this is being built from'
            DefaultBranch           = 'The default branch for this repository'
            PublishTo               = 'The various places this build might publish to'
            GitHubRepoOwner         = 'The GitHub organisation/account this repository lives in'
            GitHubRepoName          = 'The GitHub repo name'
            GitHubStageReleaseToken = 'GitHub token used during the StageRelease build, must have Read/Write pull request and Read issue permissions'
            GitHubReleaseToken      = 'GitHub token used during the Release build, must have Read/write release permissions'
            ModuleName              = 'The name of the PowerShell module being built'
            ModuleGUID              = 'The GUID of the module'
            ModuleDescription       = 'The description of the module'
            ModuleTags              = 'Any tags to add to the module'
        }

        $Plan = Get-BrownserveBuildTasksComponentPlan -ResolvedComponents $ResolvedComponents -ComponentDefinitions $ComponentDefinitions
        $AlwaysDirectSharedNames = @('BranchName', 'DefaultBranch', 'GitHubRepoOwner')
        $ConditionalSharedNames = @('ReleaseType', 'GitHubRepoName', 'GitHubStageReleaseToken', 'GitHubReleaseToken')

        $DeclaredParamNames = [System.Collections.Generic.HashSet[string]]::new()
        $ParamBlocks = [System.Collections.Generic.List[string]]::new()

        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'ReleaseType' -Mandatory $false -ValidateSet @('major', 'minor', 'patch') -Description $CommonDescriptions['ReleaseType']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'BranchName' -Mandatory $true -Description $CommonDescriptions['BranchName']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'DefaultBranch' -Mandatory $true -Description $CommonDescriptions['DefaultBranch']))
        if ($Plan.PublishToValues.Count -gt 0)
        {
            $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'PublishTo' -Type 'string[]' -Mandatory $false -ValidateSet $Plan.PublishToValues -Description $CommonDescriptions['PublishTo']))
        }
        else
        {
            $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'PublishTo' -Type 'string[]' -Mandatory $false -Description $CommonDescriptions['PublishTo']))
        }
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubRepoOwner' -Mandatory $true -Description $CommonDescriptions['GitHubRepoOwner']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubRepoName' -Mandatory $false -DefaultExpression '$Global:BrownserveRepoName' -Description $CommonDescriptions['GitHubRepoName']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubStageReleaseToken' -Mandatory $false -Description $CommonDescriptions['GitHubStageReleaseToken']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubReleaseToken' -Mandatory $false -Description $CommonDescriptions['GitHubReleaseToken']))
        $Plan.ReleaseLifecycleParameterNames | ForEach-Object { $DeclaredParamNames.Add($_) | Out-Null }

        foreach ($TaskComponent in $Plan.OtherComponents)
        {
            if ($TaskComponent.BuildTasks.ModuleInfoMap)
            {
                foreach ($TaskParamName in ($TaskComponent.BuildTasks.ModuleInfoMap.Keys | Sort-Object))
                {
                    if ($DeclaredParamNames.Contains($TaskParamName))
                    {
                        continue
                    }
                    $ModuleInfoParamType = if ($TaskParamName -eq 'ModuleGUID') { 'guid' } elseif ($TaskParamName -eq 'ModuleTags') { 'string[]' } else { 'string' }
                    $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name $TaskParamName -Type $ModuleInfoParamType -Mandatory $true -Description $CommonDescriptions[$TaskParamName]))
                    $DeclaredParamNames.Add($TaskParamName) | Out-Null
                }
            }
            foreach ($RuntimeName in $TaskComponent.RuntimeParameterNames)
            {
                if ($DeclaredParamNames.Contains($RuntimeName))
                {
                    continue
                }
                $RuntimeType = 'string'
                if ($TaskComponent.BuildTasks.Types.ContainsKey($RuntimeName))
                {
                    $RuntimeType = $TaskComponent.BuildTasks.Types[$RuntimeName]
                }
                $RuntimeDefault = $null
                if ($TaskComponent.BuildTasks.Defaults -and $TaskComponent.BuildTasks.Defaults.ContainsKey($RuntimeName))
                {
                    $RuntimeDefault = "'$($TaskComponent.BuildTasks.Defaults[$RuntimeName])'"
                }
                $RuntimeDescription = $null
                if ($TaskComponent.BuildTasks.Descriptions -and $TaskComponent.BuildTasks.Descriptions.ContainsKey($RuntimeName))
                {
                    $RuntimeDescription = $TaskComponent.BuildTasks.Descriptions[$RuntimeName]
                }
                $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name $RuntimeName -Type $RuntimeType -Mandatory $false -DefaultExpression $RuntimeDefault -Description $RuntimeDescription))
                $DeclaredParamNames.Add($RuntimeName) | Out-Null
            }
        }

        $ParamBlockText = ($ParamBlocks -join ",`n`n")

        $BodyLines = [System.Collections.Generic.List[string]]::new()
        $BodyLines.Add('if (!$GitHubRepoName)')
        $BodyLines.Add('{')
        $BodyLines.Add("    throw 'GitHubRepoName not set'")
        $BodyLines.Add('}')
        $BodyLines.Add("`$BranchName = `$BranchName -replace 'refs\/heads\/', ''")
        $BodyLines.Add('')
        if ($Plan.UseWorkingCopyTasks)
        {
            $BodyLines.Add("`$TasksDirectory = Join-Path `$Global:BrownserveRepoRootDirectory 'tasks'")
        }
        else
        {
            $BodyLines.Add("`$TasksDirectory = Join-Path `$Global:BrownserveRepoNugetPackagesDirectory 'Brownserve.PSBuildTasks' 'tasks'")
        }
        $BodyLines.Add('')

        $ReleaseLifecyclePairs = [ordered]@{
            BranchName      = '$BranchName'
            DefaultBranch   = '$DefaultBranch'
            GitHubRepoOwner = '$GitHubRepoOwner'
            GitHubRepoName  = '$GitHubRepoName'
        }
        (Format-BrownserveAlignedHashtable -VariableName 'ReleaseLifecycleParams' -Pairs $ReleaseLifecyclePairs) | ForEach-Object { $BodyLines.Add($_) }
        $BodyLines.Add('if ($ReleaseType) { $ReleaseLifecycleParams.Add(''ReleaseType'', $ReleaseType) }')
        $BodyLines.Add('if ($PublishTo) { $ReleaseLifecycleParams.Add(''PublishTo'', $PublishTo) }')
        $BodyLines.Add('if ($GitHubStageReleaseToken) { $ReleaseLifecycleParams.Add(''GitHubStageReleaseToken'', $GitHubStageReleaseToken) }')
        $BodyLines.Add('if ($GitHubReleaseToken) { $ReleaseLifecycleParams.Add(''GitHubReleaseToken'', $GitHubReleaseToken) }')
        $BodyLines.Add((". (Join-Path `$TasksDirectory '$($Plan.ReleaseLifecycleComponent.BuildTasks.TaskFile)') @ReleaseLifecycleParams"))
        $BodyLines.Add('')

        foreach ($TaskComponent in $Plan.OtherComponents)
        {
            $BuildTasksData = $TaskComponent.BuildTasks
            $ParamsVarName = "$($TaskComponent.Name)Params"

            $Pairs = [ordered]@{}
            foreach ($SharedName in $AlwaysDirectSharedNames)
            {
                if ($BuildTasksData.Parameters -contains $SharedName)
                {
                    $Pairs[$SharedName] = "`$$SharedName"
                }
            }
            foreach ($OptionKey in ($BuildTasksData.OptionParameterMap.Keys | Sort-Object))
            {
                $TaskParamName = $BuildTasksData.OptionParameterMap[$OptionKey]
                $Pairs[$TaskParamName] = ConvertTo-BrownserveBuildScriptLiteral -Value $TaskComponent.Options[$OptionKey]
            }
            if ($BuildTasksData.ModuleInfoMap)
            {
                foreach ($TaskParamName in ($BuildTasksData.ModuleInfoMap.Keys | Sort-Object))
                {
                    $Pairs[$TaskParamName] = "`$$TaskParamName"
                }
            }
            (Format-BrownserveAlignedHashtable -VariableName $ParamsVarName -Pairs $Pairs) | ForEach-Object { $BodyLines.Add($_) }

            if ($BuildTasksData.Parameters -contains 'PublishTo')
            {
                $PublishValuesLiteral = (@($BuildTasksData.PublishValues | ForEach-Object { "'$_'" }) -join ', ')
                $FilteredVarName = "$($ParamsVarName)PublishTo"
                $BodyLines.Add("`$$FilteredVarName = @(`$PublishTo | Where-Object { `$_ -in @($PublishValuesLiteral) })")
                $BodyLines.Add("if (`$$FilteredVarName.Count -gt 0) { `$$ParamsVarName.Add('PublishTo', `$$FilteredVarName) }")
            }
            foreach ($SharedName in $ConditionalSharedNames)
            {
                if ($BuildTasksData.Parameters -contains $SharedName)
                {
                    $BodyLines.Add("if (`$$SharedName) { `$$ParamsVarName.Add('$SharedName', `$$SharedName) }")
                }
            }
            foreach ($RuntimeName in $TaskComponent.RuntimeParameterNames)
            {
                $RuntimeType = 'string'
                if ($BuildTasksData.Types.ContainsKey($RuntimeName))
                {
                    $RuntimeType = $BuildTasksData.Types[$RuntimeName]
                }
                if ($RuntimeType -eq 'switch')
                {
                    $BodyLines.Add("`$$ParamsVarName.Add('$RuntimeName', (`$$RuntimeName -eq `$true))")
                }
                else
                {
                    $BodyLines.Add("if (`$$RuntimeName) { `$$ParamsVarName.Add('$RuntimeName', `$$RuntimeName) }")
                }
            }
            $BodyLines.Add((". (Join-Path `$TasksDirectory '$($BuildTasksData.TaskFile)') @$ParamsVarName"))
            $BodyLines.Add('')
        }

        $BodyLines.Add((". (Join-Path `$Global:BrownserveRepoBuildTasksDirectory 'custom.tasks.ps1')"))

        $BodyText = ($BodyLines -join "`n")

        $ScriptContent = @"
<#
.SYNOPSIS
    This contains the build tasks for Invoke-Build to use.
#>
[CmdletBinding()]
param
(
$ParamBlockText
)
$BodyText
"@
        return $ScriptContent
    }
}
