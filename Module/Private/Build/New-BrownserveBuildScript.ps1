<#
.SYNOPSIS
    Generates the content of a thin 'build.ps1' for a repository's resolved components.
.DESCRIPTION
    Emits the common parameters (branch detection, 'Build' target selection, release/publish parameters)
    plus every parameter a component's 'BuildTasks' data exposes to the caller, dot-sources '_init.ps1',
    validates that the toolchains the requested target needs are on PATH, and forwards only the supplied
    parameters to 'Invoke-Build build_tasks.ps1'. Toolchain requirements are per target (or the anchors a
    target reaches, e.g. 'cargo' is needed wherever RustBinary's Build/Test/Package/Stage contributions
    run, but not by targets that only reach the Stage anchor for other components) and can be conditioned
    on platform (e.g. 'mono' is only required on non-Windows).
#>
function New-BrownserveBuildScript
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

        # The GitHub organisation/account that owns this repository
        [Parameter(Mandatory = $false)]
        [string]
        $Owner = 'Brownserve-UK',

        # The name of the repository, used to build up the default GitHubRepoName
        [Parameter(Mandatory = $false)]
        [string]
        $RepoName,

        # The PowerShell module information, if the 'PowerShellModule' component is present
        [Parameter(Mandatory = $false)]
        [psobject]
        $ModuleInfo
    )
    process
    {
        $CommonDescriptions = @{
            ModuleInfo              = 'The PowerShell module information to use'
            DefaultBranch           = 'The name of the default branch'
            BranchName              = 'The name of the branch you are running on, this is used to work out if the release is production or pre-release'
            ReleaseType             = 'When preparing a release this denotes the type of changes that have been made, used to determine the version number to use for the release'
            PublishTo               = 'The various places to publish to'
            GitHubRepoOwner         = 'The GitHub organisation/account that owns this repository'
            GitHubRepoName          = 'The GitHub repo that contains this repository'
            GitHubStageReleaseToken = 'GitHub token used during the StageRelease build, must have Read/Write pull request and Read issue permissions'
            GitHubReleaseToken      = 'GitHub token used during the Release build, must have Read/write release permissions'
        }

        $Plan = Get-BrownserveBuildTasksComponentPlan -ResolvedComponents $ResolvedComponents -ComponentDefinitions $ComponentDefinitions

        $PublicTargets = $Plan.PublicTargets
        $MetaTargets = @($Plan.MetaTargetAnchors.Keys)
        $BuildValidateSet = @($MetaTargets + $PublicTargets | Select-Object -Unique)
        $DefaultBuild = if ($Plan.IsPowerShellModule) { 'BuildWithDocs' } else { 'Build' }
        if ($Plan.IsPowerShellModule)
        {
            $BuildValidateSet = @($BuildValidateSet + @('BuildAndImport', 'BuildWithDocs') | Select-Object -Unique)
        }

        $DeclaredParamNames = [System.Collections.Generic.HashSet[string]]::new()
        $ParamBlocks = [System.Collections.Generic.List[string]]::new()

        if ($Plan.IsPowerShellModule)
        {
            $ParamBlocks.Add(@"
    # $($CommonDescriptions['ModuleInfo'])
    [Parameter(
        Mandatory = `$false
    )]
    [ValidateNotNullOrEmpty()]
    [psobject]
    `$ModuleInfo
"@)
        }
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'DefaultBranch' -Mandatory $false -DefaultExpression "'main'" -Description $CommonDescriptions['DefaultBranch']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'BranchName' -Mandatory $false -Description $CommonDescriptions['BranchName']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'Build' -Mandatory $false -ValidateSet $BuildValidateSet -DefaultExpression "'$DefaultBuild'" -Description 'The build to run'))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'ReleaseType' -Mandatory $false -ValidateSet @('major', 'minor', 'patch') -DefaultExpression "'minor'" -Description $CommonDescriptions['ReleaseType']))
        if ($Plan.PublishToValues.Count -gt 0)
        {
            $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'PublishTo' -Type 'string[]' -Mandatory $false -ValidateSet $Plan.PublishToValues -Description $CommonDescriptions['PublishTo']))
        }
        else
        {
            $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'PublishTo' -Type 'string[]' -Mandatory $false -Description $CommonDescriptions['PublishTo']))
        }
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubRepoOwner' -Mandatory $false -DefaultExpression "'$Owner'" -Description $CommonDescriptions['GitHubRepoOwner']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubRepoName' -Mandatory $false -Description $CommonDescriptions['GitHubRepoName']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubStageReleaseToken' -Mandatory $false -Description $CommonDescriptions['GitHubStageReleaseToken']))
        $ParamBlocks.Add((Format-BrownserveBuildScriptParameter -Name 'GitHubReleaseToken' -Mandatory $false -Description $CommonDescriptions['GitHubReleaseToken']))
        $Plan.ReleaseLifecycleParameterNames | ForEach-Object { $DeclaredParamNames.Add($_) | Out-Null }

        foreach ($TaskComponent in $Plan.OtherComponents)
        {
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

        $ToolchainLines = [System.Collections.Generic.List[string]]::new()
        $ToolchainLines.Add('$RequiredToolchains = @(')
        foreach ($Requirement in (Get-BrownserveToolchainRequirement -Plan $Plan))
        {
            $ToolsLiteral = (@($Requirement.Tools | ForEach-Object { "'$_'" }) -join ', ')
            $TargetsLiteral = (@($Requirement.Targets | ForEach-Object { "'$_'" }) -join ', ')
            $SkipIfExpression = '{ $false }'
            if ($Requirement.CollectorParameter)
            {
                $SkipIfExpression = "{ `$$($Requirement.CollectorParameter) }"
            }
            $PlatformLiteral = if ($Requirement.Platform) { "'$($Requirement.Platform)'" } else { '$null' }
            $ToolchainLines.Add("    @{ Component = '$($Requirement.Component)'; Tools = @($ToolsLiteral); Targets = @($TargetsLiteral); Platform = $PlatformLiteral; SkipIf = $SkipIfExpression }")
        }
        $ToolchainLines.Add(')')

        $BodyLines = [System.Collections.Generic.List[string]]::new()
        $BodyLines.Add("`$ErrorActionPreference = 'Stop'")
        $BodyLines.Add('if (!$BranchName)')
        $BodyLines.Add('{')
        $BodyLines.Add('    $BranchName = & git rev-parse --abbrev-ref HEAD')
        $BodyLines.Add('}')
        $BodyLines.Add('if (!$BranchName)')
        $BodyLines.Add('{')
        $BodyLines.Add("    `$BranchName = 'preview'")
        $BodyLines.Add('}')
        $BodyLines.Add("`$BranchName = `$BranchName -replace 'refs\/heads\/', ''")
        $BodyLines.Add('')

        if ($Plan.IsPowerShellModule)
        {
            $BodyLines.Add('if (!$ModuleInfo)')
            $BodyLines.Add('{')
            $BodyLines.Add('    try')
            $BodyLines.Add('    {')
            $BodyLines.Add("        `$ModuleInfo = Get-Content (Join-Path `$PSScriptRoot 'ModuleInfo.json') -Raw | ConvertFrom-Json")
            $BodyLines.Add('    }')
            $BodyLines.Add('    catch')
            $BodyLines.Add('    {')
            $BodyLines.Add("        throw 'Failed to load module information.'")
            $BodyLines.Add('    }')
            $BodyLines.Add('    Write-Verbose "Loaded module information from ModuleInfo.json:`n$($ModuleInfo | Out-String)"')
            $BodyLines.Add('}')
            $BodyLines.Add('')
        }

        $BodyLines.Add('try')
        $BodyLines.Add('{')
        $BodyLines.Add("    Write-Verbose 'Starting build script'")
        $BodyLines.Add("    `$initScriptPath = Join-Path `$PSScriptRoot -ChildPath '_init.ps1' | Convert-Path")
        $BodyLines.Add('    . $initScriptPath')
        $BodyLines.Add('}')
        $BodyLines.Add('catch')
        $BodyLines.Add('{')
        $BodyLines.Add('    Write-Error "Failed to init repo.`n$($_.Exception.Message)"')
        $BodyLines.Add('}')
        $BodyLines.Add('')

        $ToolchainLines | ForEach-Object { $BodyLines.Add($_) }
        $BodyLines.Add('$MissingTools = [System.Collections.Generic.List[string]]::new()')
        $BodyLines.Add('foreach ($Requirement in $RequiredToolchains)')
        $BodyLines.Add('{')
        $BodyLines.Add('    if ($Requirement.Targets -notcontains $Build)')
        $BodyLines.Add('    {')
        $BodyLines.Add('        continue')
        $BodyLines.Add('    }')
        $BodyLines.Add('    if (& $Requirement.SkipIf)')
        $BodyLines.Add('    {')
        $BodyLines.Add('        continue')
        $BodyLines.Add('    }')
        $BodyLines.Add('    if ($Requirement.Platform -eq ''Windows'' -and -not $IsWindows)')
        $BodyLines.Add('    {')
        $BodyLines.Add('        continue')
        $BodyLines.Add('    }')
        $BodyLines.Add('    if ($Requirement.Platform -eq ''NonWindows'' -and $IsWindows)')
        $BodyLines.Add('    {')
        $BodyLines.Add('        continue')
        $BodyLines.Add('    }')
        $BodyLines.Add('    foreach ($Tool in $Requirement.Tools)')
        $BodyLines.Add('    {')
        $BodyLines.Add('        if (!(Get-Command $Tool -ErrorAction SilentlyContinue))')
        $BodyLines.Add('        {')
        $BodyLines.Add('            $MissingTools.Add("''$Tool'' (required by $($Requirement.Component))")')
        $BodyLines.Add('        }')
        $BodyLines.Add('    }')
        $BodyLines.Add('}')
        $BodyLines.Add('if ($MissingTools.Count -gt 0)')
        $BodyLines.Add('{')
        $BodyLines.Add('    throw "The following tools are required to run this build but were not found on PATH:`n$($MissingTools -join "`n")"')
        $BodyLines.Add('}')
        $BodyLines.Add('')

        $BodyLines.Add('try')
        $BodyLines.Add('{')
        $BodyLines.Add('    $BuildParams = @{')
        $BodyLines.Add("        File          = (Join-Path -Path `$global:BrownserveRepoBuildTasksDirectory -ChildPath 'build_tasks.ps1' | Convert-Path)")
        $BodyLines.Add('        Task          = $Build')
        $BodyLines.Add('        BranchName    = $BranchName')
        $BodyLines.Add('        DefaultBranch = $DefaultBranch')
        if ($Plan.IsPowerShellModule)
        {
            $BodyLines.Add('        ModuleName        = $ModuleInfo.Name')
            $BodyLines.Add('        ModuleDescription = $ModuleInfo.Description')
            $BodyLines.Add('        ModuleGUID        = $ModuleInfo.GUID')
            $BodyLines.Add('        ModuleTags        = $ModuleInfo.Tags')
        }
        $BodyLines.Add('    }')
        $BodyLines.Add('    if ($ReleaseType) { $BuildParams.Add(''ReleaseType'', $ReleaseType) }')
        $BodyLines.Add('    if ($GitHubRepoOwner) { $BuildParams.Add(''GitHubRepoOwner'', $GitHubRepoOwner) }')
        $BodyLines.Add('    if ($GitHubRepoName) { $BuildParams.Add(''GitHubRepoName'', $GitHubRepoName) }')
        $BodyLines.Add('    if ($GitHubStageReleaseToken) { $BuildParams.Add(''GitHubStageReleaseToken'', $GitHubStageReleaseToken) }')
        $BodyLines.Add('    if ($GitHubReleaseToken) { $BuildParams.Add(''GitHubReleaseToken'', $GitHubReleaseToken) }')
        $BodyLines.Add('    if ($PublishTo) { $BuildParams.Add(''PublishTo'', $PublishTo) }')
        foreach ($TaskComponent in $Plan.OtherComponents)
        {
            foreach ($RuntimeName in $TaskComponent.RuntimeParameterNames)
            {
                $RuntimeType = 'string'
                if ($TaskComponent.BuildTasks.Types.ContainsKey($RuntimeName))
                {
                    $RuntimeType = $TaskComponent.BuildTasks.Types[$RuntimeName]
                }
                if ($RuntimeType -eq 'switch')
                {
                    $BodyLines.Add("    `$BuildParams.Add('$RuntimeName', (`$PSBoundParameters['$RuntimeName'] -eq `$true))")
                }
                else
                {
                    $BodyLines.Add("    if (`$$RuntimeName) { `$BuildParams.Add('$RuntimeName', `$$RuntimeName) }")
                }
            }
        }
        $BodyLines.Add('    Write-Verbose "Invoking build: $Build"')
        $BodyLines.Add("    Invoke-Build @BuildParams -Verbose:(`$PSBoundParameters['Verbose'] -eq `$true)")
        $BodyLines.Add('}')
        $BodyLines.Add('catch')
        $BodyLines.Add('{')
        $BodyLines.Add('    Write-Error $_.Exception.Message')
        $BodyLines.Add('}')

        $BodyText = ($BodyLines -join "`n")

        $ScriptContent = @"
<#
.SYNOPSIS
    Builds, tests and releases this repository via Invoke-Build and Pester.
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
