#requires -Modules Pester

BeforeDiscovery {
    $SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
    $BuildTasksCases = @(Get-ChildItem -Path $SnapshotsRoot -Directory | Where-Object {
            Test-Path (Join-Path $_.FullName '.build' 'tasks' 'build_tasks.ps1')
        })
}

BeforeAll {
    function Get-BrownserveGeneratedParameterInfo
    {
        param ($Content)
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$null, [ref]$null)
        $Results = [System.Collections.Generic.List[object]]::new()
        foreach ($Param in $Ast.ParamBlock.Parameters)
        {
            $Name = $Param.Name.VariablePath.UserPath
            $TypeConstraint = $Param.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] } | Select-Object -First 1
            $TypeName = if ($TypeConstraint) { $TypeConstraint.TypeName.Name } else { 'string' }
            $ParamAttr = $Param.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' } | Select-Object -First 1
            $Mandatory = $false
            if ($ParamAttr)
            {
                $MandatoryArg = $ParamAttr.NamedArguments | Where-Object { $_.ArgumentName -eq 'Mandatory' } | Select-Object -First 1
                if ($MandatoryArg)
                {
                    $Mandatory = [bool]$MandatoryArg.Argument.SafeGetValue()
                }
            }
            $ValidateSetAttr = $Param.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' } | Select-Object -First 1
            $ValidateSetValues = @()
            if ($ValidateSetAttr)
            {
                $ValidateSetValues = @($ValidateSetAttr.PositionalArguments | ForEach-Object { $_.SafeGetValue() })
            }
            $Results.Add([pscustomobject]@{ Name = $Name; Type = $TypeName; Mandatory = $Mandatory; ValidateSet = $ValidateSetValues })
        }
        return $Results
    }

    function Get-BrownserveDummyParameterValue
    {
        param ($ParamInfo, $Seed)
        switch ($ParamInfo.Type)
        {
            'guid'
            {
                return [guid]::NewGuid()
            }
            'string[]'
            {
                if ($ParamInfo.ValidateSet.Count -gt 0)
                {
                    return @($ParamInfo.ValidateSet[0])
                }
                return @("$Seed-value")
            }
            'hashtable[]'
            {
                return @()
            }
            default
            {
                if ($ParamInfo.ValidateSet.Count -gt 0)
                {
                    return $ParamInfo.ValidateSet[0]
                }
                return "$Seed-$($ParamInfo.Name)"
            }
        }
    }

    function Get-BrownserveValidateSetValues
    {
        param ($Content, $ParameterName)
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$null, [ref]$null)
        $Param = $Ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq $ParameterName } | Select-Object -First 1
        if (!$Param)
        {
            return $null
        }
        $ValidateSetAttr = $Param.Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateSet' } | Select-Object -First 1
        if (!$ValidateSetAttr)
        {
            return $null
        }
        return @($ValidateSetAttr.PositionalArguments | ForEach-Object { $_.SafeGetValue() })
    }

    $script:PinnedTasksDir = Join-Path $Global:BrownserveRepoNugetPackagesDirectory 'Brownserve.PSBuildTasks' 'tasks'
    if (!(Test-Path $script:PinnedTasksDir))
    {
        throw "Pinned task files not found at '$($script:PinnedTasksDir)'. Restore 'Brownserve.PSBuildTasks' via paket (or populate the test scratchpad's packages directory) before running this test."
    }

    $script:InvokeBuildScript = Get-Command 'Invoke-Build' -ErrorAction 'Stop'
}

Describe 'build_tasks.ps1 task graphs' {
    Context '<_.Name>' -ForEach $BuildTasksCases {
        BeforeEach {
            $CaseDir = $_.FullName
            $CaseName = $_.Name
            $Drive = Join-Path $TestDrive $CaseName
            New-Item $Drive -ItemType Directory -Force | Out-Null

            $BuildTasksSourcePath = Join-Path $CaseDir '.build' 'tasks' 'build_tasks.ps1'
            $CustomTasksSourcePath = Join-Path $CaseDir '.build' 'tasks' 'custom.tasks.ps1'
            $BuildScriptSourcePath = Join-Path $CaseDir '.build' 'build.ps1'

            $TasksDestDir = Join-Path $Drive '.build' 'tasks'
            New-Item $TasksDestDir -ItemType Directory -Force | Out-Null
            Copy-Item -Path $BuildTasksSourcePath -Destination (Join-Path $TasksDestDir 'build_tasks.ps1')
            Copy-Item -Path $CustomTasksSourcePath -Destination (Join-Path $TasksDestDir 'custom.tasks.ps1')

            $BuildTasksContent = Get-Content -Path $BuildTasksSourcePath -Raw
            $UsesWorkingCopy = $BuildTasksContent -match [regex]::Escape("Join-Path `$Global:BrownserveRepoRootDirectory 'tasks'")
            if ($UsesWorkingCopy)
            {
                $PackagedTasksDir = Join-Path $Drive 'tasks'
            }
            else
            {
                $PackagedTasksDir = Join-Path $Drive 'packages' 'Brownserve.PSBuildTasks' 'tasks'
            }
            New-Item $PackagedTasksDir -ItemType Directory -Force | Out-Null
            Get-ChildItem -Path $script:PinnedTasksDir -Filter '*.tasks.ps1' | Copy-Item -Destination $PackagedTasksDir

            $script:OriginalGlobals = @{}
            Get-Variable -Scope Global -Name 'Brownserve*' | ForEach-Object { $script:OriginalGlobals[$_.Name] = $_.Value }
            $script:OriginalGlobalNames = @($script:OriginalGlobals.Keys)

            $script:CaseGlobals = [ordered]@{
                BrownserveRepoRootDirectory          = $Drive
                BrownserveRepoNugetPackagesDirectory = Join-Path $Drive 'packages'
                BrownserveRepoBuildTasksDirectory    = $TasksDestDir
                BrownserveRepoName                   = $CaseName
                BrownserveRepoBuildOutputDirectory   = Join-Path $Drive 'output'
                BrownserveModuleDirectory            = Join-Path $Drive 'Module'
            }
            foreach ($Key in $script:CaseGlobals.Keys)
            {
                Set-Variable -Name $Key -Value $script:CaseGlobals[$Key] -Scope Global
            }

            $script:BuildScriptContent = Get-Content -Path $BuildScriptSourcePath -Raw
            $script:BuildTasksDestPath = Join-Path $TasksDestDir 'build_tasks.ps1'
            $TasksParamInfo = Get-BrownserveGeneratedParameterInfo -Content (Get-Content -Path $script:BuildTasksDestPath -Raw)

            $script:DummyParams = @{ GitHubRepoOwner = 'Brownserve-UK'; GitHubRepoName = $CaseName; BranchName = 'feature/test'; DefaultBranch = 'main' }
            foreach ($ParamInfo in $TasksParamInfo)
            {
                if ($ParamInfo.Mandatory -and -not $script:DummyParams.ContainsKey($ParamInfo.Name))
                {
                    $script:DummyParams[$ParamInfo.Name] = Get-BrownserveDummyParameterValue -ParamInfo $ParamInfo -Seed $CaseName
                }
            }
        }

        AfterEach {
            foreach ($Key in $script:OriginalGlobals.Keys)
            {
                Set-Variable -Name $Key -Value $script:OriginalGlobals[$Key] -Scope Global
            }
            Get-Variable -Scope Global -Name 'Brownserve*' | Where-Object { $_.Name -notin $script:OriginalGlobalNames } | ForEach-Object {
                Remove-Variable -Name $_.Name -Scope Global -ErrorAction SilentlyContinue
            }
        }

        It 'loads without executing task bodies and every -Build ValidateSet target exists as a task' {
            $ExpectedTargets = Get-BrownserveValidateSetValues -Content $script:BuildScriptContent -ParameterName 'Build'
            $ExpectedTargets | Should -Not -BeNullOrEmpty

            $Tasks = & $script:InvokeBuildScript '?' -File $script:BuildTasksDestPath @script:DummyParams
            $TaskNames = @($Tasks | ForEach-Object { $_.Name })

            $MissingTargets = @($ExpectedTargets | Where-Object { $_ -notin $TaskNames })
            $MissingTargets | Should -BeNullOrEmpty -Because "these targets are in build.ps1's -Build ValidateSet but have no matching task"
        }

        It 'loads with the full PublishTo union without failing parameter binding' {
            $UnionValues = Get-BrownserveValidateSetValues -Content $script:BuildScriptContent -ParameterName 'PublishTo'
            if (!$UnionValues)
            {
                Set-ItResult -Skipped -Because 'this repository shape has no PublishTo ValidateSet'
                return
            }

            $ParamsWithPublishTo = @{} + $script:DummyParams
            $ParamsWithPublishTo['PublishTo'] = $UnionValues

            { & $script:InvokeBuildScript '?' -File $script:BuildTasksDestPath @ParamsWithPublishTo } | Should -Not -Throw
        }
    }
}

Describe 'Generated build.ps1 files parse cleanly' {
    It 'parses <_.Name>''s build.ps1 without errors' -ForEach $BuildTasksCases {
        $BuildScriptPath = Join-Path $_.FullName '.build' 'build.ps1'
        $Errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($BuildScriptPath, [ref]$null, [ref]$Errors) | Out-Null
        $Errors | Should -BeNullOrEmpty
    }
}
