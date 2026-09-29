#requires -Modules Pester

$SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
$WorkflowCases = @(
    Get-ChildItem -Path $SnapshotsRoot -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName '.github' 'workflows') } |
        ForEach-Object { @{ CaseName = $_.Name } }
)
$BuildsCases = @($WorkflowCases | Where-Object { Test-Path (Join-Path $SnapshotsRoot $_.CaseName '.github' 'workflows' 'builds.yaml') })
$DependabotCases = @(
    Get-ChildItem -Path $SnapshotsRoot -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName '.github' 'dependabot.yml') } |
        ForEach-Object { @{ CaseName = $_.Name } }
)

if ($WorkflowCases.Count -eq 0 -or $BuildsCases.Count -eq 0 -or $DependabotCases.Count -eq 0)
{
    throw "No snapshots with workflows were found under '$SnapshotsRoot'."
}

BeforeAll {
    $YamlModule = Get-ChildItem -Path (Join-Path $global:BrownserveRepoNugetPackagesDirectory 'powershell-yaml') -Filter 'powershell-yaml.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$YamlModule)
    {
        throw "The powershell-yaml module was not found under '$global:BrownserveRepoNugetPackagesDirectory'. Run _init.ps1 (or Save-Module powershell-yaml into that directory) before running this test."
    }
    Import-Module $YamlModule.FullName -Force -Verbose:$false

    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false
    $script:CoreGitHubData = InModuleScope Brownserve.PSBuildTools {
        (Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop')['Core'].Data.GitHubActions
    }
    $script:SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
}

Describe 'Generated snapshot workflows' {
    Context '<CaseName>' -ForEach $WorkflowCases {
        BeforeAll {
            $script:WorkflowDirectory = Join-Path $script:SnapshotsRoot $CaseName '.github' 'workflows'
        }

        It 'parses every workflow as YAML' {
            foreach ($File in Get-ChildItem -Path $script:WorkflowDirectory -Filter '*.yaml')
            {
                { ConvertFrom-Yaml (Get-Content -Path $File.FullName -Raw) } | Should -Not -Throw
            }
        }

        It 'pins every Brownserve-UK/actions reference to the Core commit' {
            $Pattern = '^Brownserve-UK/actions/\.github/workflows/brownserve-[a-z-]+\.yaml@' + $script:CoreGitHubData.ActionsCommit + ' # ' + [regex]::Escape($script:CoreGitHubData.ActionsVersion) + '$'
            foreach ($File in Get-ChildItem -Path $script:WorkflowDirectory -Filter '*.yaml')
            {
                foreach ($Line in (Get-Content -Path $File.FullName | Where-Object { $_ -match 'Brownserve-UK/actions' }))
                {
                    ($Line -replace '^\s+uses:\s+', '') | Should -Match $Pattern
                }
            }
        }

        It 'never uses secrets: inherit' {
            foreach ($File in Get-ChildItem -Path $script:WorkflowDirectory -Filter '*.yaml')
            {
                Get-Content -Path $File.FullName -Raw | Should -Not -Match 'secrets:\s*inherit'
            }
        }
    }

    Context 'builds.yaml in <CaseName>' -ForEach $BuildsCases {
        BeforeAll {
            $script:BuildsYaml = ConvertFrom-Yaml (Get-Content -Path (Join-Path $script:SnapshotsRoot $CaseName '.github' 'workflows' 'builds.yaml') -Raw) -Ordered
        }

        It 'has a merge-checks job that runs always' {
            $script:BuildsYaml.jobs.Keys | Should -Contain 'merge-checks'
            $script:BuildsYaml.jobs['merge-checks']['if'] | Should -Be 'always()'
        }

        It 'needs exactly the CI jobs' {
            $CIJobs = @($script:BuildsYaml.jobs.Keys | Where-Object { $_ -ne 'merge-checks' } | Sort-Object)
            $CIJobs.Count | Should -BeGreaterThan 0
            @($script:BuildsYaml.jobs['merge-checks'].needs | Sort-Object) | Should -Be $CIJobs
        }

        It 'calls the reusable pr-build workflow for every CI job' {
            foreach ($Name in ($script:BuildsYaml.jobs.Keys | Where-Object { $_ -ne 'merge-checks' }))
            {
                $script:BuildsYaml.jobs[$Name].uses | Should -Match 'brownserve-pr-build\.yaml@'
            }
        }

        It 'keeps template expressions out of the merge-checks script' {
            $Step = $script:BuildsYaml.jobs['merge-checks'].steps[0]
            $Step.run | Should -Not -Match '\$\{\{'
            $Step.env.Count | Should -BeGreaterThan 0
        }

        It 'does no checkout in merge-checks' {
            $script:BuildsYaml.jobs['merge-checks'].steps | ForEach-Object { $_.Keys | Should -Not -Contain 'uses' }
        }
    }
}

Describe 'Generated dependabot configuration' {
    It 'ignores Brownserve-UK/actions for github-actions only in <CaseName>' -ForEach $DependabotCases {
        $Yaml = ConvertFrom-Yaml (Get-Content -Path (Join-Path $script:SnapshotsRoot $CaseName '.github' 'dependabot.yml') -Raw) -Ordered
        $Actions = @($Yaml.updates | Where-Object { $_['package-ecosystem'] -eq 'github-actions' })
        $Actions.Count | Should -Be 1
        @($Actions[0].ignore).Count | Should -Be 1
        $Actions[0].ignore[0]['dependency-name'] | Should -Be 'Brownserve-UK/actions*'
        foreach ($Update in ($Yaml.updates | Where-Object { $_['package-ecosystem'] -ne 'github-actions' }))
        {
            $Update.Keys | Should -Not -Contain 'ignore'
        }
    }
}
