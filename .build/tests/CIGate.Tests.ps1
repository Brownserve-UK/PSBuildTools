#requires -Modules Pester

$GateCases = @(
    @{ CaseName = 'PowerShellModule'; Label = 'a single CI job'; JobCount = 1 }
    @{ CaseName = 'bsdev'; Label = 'two CI jobs'; JobCount = 2 }
)

BeforeAll {
    $YamlModule = Get-ChildItem -Path (Join-Path $global:BrownserveRepoNugetPackagesDirectory 'powershell-yaml') -Filter 'powershell-yaml.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$YamlModule)
    {
        throw "The powershell-yaml module was not found under '$global:BrownserveRepoNugetPackagesDirectory'. Run _init.ps1 (or Save-Module powershell-yaml into that directory) before running this test."
    }
    Import-Module $YamlModule.FullName -Force -Verbose:$false
    $script:SnapshotsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'snapshots'
    $script:BashAvailable = [bool](Get-Command bash -ErrorAction SilentlyContinue)

    function Get-MergeChecksStep
    {
        param ($CaseName)
        $Path = Join-Path $script:SnapshotsRoot $CaseName '.github' 'workflows' 'builds.yaml'
        $Yaml = ConvertFrom-Yaml (Get-Content -Path $Path -Raw) -Ordered
        return $Yaml.jobs['merge-checks'].steps[0]
    }

    function Invoke-MergeChecksScript
    {
        param ($Step, $Results)
        $Saved = @{}
        foreach ($Name in $Step.env.Keys)
        {
            $Saved[$Name] = [Environment]::GetEnvironmentVariable($Name)
            [Environment]::SetEnvironmentVariable($Name, $Results[$Name])
        }
        try
        {
            $Output = & bash -c $Step.run 2>&1
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($Output -join "`n") }
        }
        finally
        {
            foreach ($Name in $Saved.Keys)
            {
                [Environment]::SetEnvironmentVariable($Name, $Saved[$Name])
            }
        }
    }
}

Describe 'merge-checks gate behaviour' {
    Context 'with <Label>' -ForEach $GateCases {
        BeforeAll {
            $script:Step = Get-MergeChecksStep -CaseName $CaseName
            $script:EnvNames = @($script:Step.env.Keys)
        }

        It 'reads one result per CI job' {
            $script:EnvNames.Count | Should -Be $JobCount
        }

        It 'passes when every job succeeded' {
            if (!$script:BashAvailable)
            {
                Set-ItResult -Skipped -Because 'bash is not available on this machine'
                return
            }
            $Results = @{}
            $script:EnvNames | ForEach-Object { $Results[$_] = 'success' }
            $Run = Invoke-MergeChecksScript -Step $script:Step -Results $Results
            $Run.ExitCode | Should -Be 0
        }

        It 'fails when a job reports <State>' -ForEach @(
            @{ State = 'failure' }
            @{ State = 'cancelled' }
            @{ State = 'skipped' }
        ) {
            if (!$script:BashAvailable)
            {
                Set-ItResult -Skipped -Because 'bash is not available on this machine'
                return
            }
            foreach ($Failing in $script:EnvNames)
            {
                $Results = @{}
                $script:EnvNames | ForEach-Object { $Results[$_] = 'success' }
                $Results[$Failing] = $State
                $Run = Invoke-MergeChecksScript -Step $script:Step -Results $Results
                $Run.ExitCode | Should -Be 1 -Because "$Failing was $State"
                $Run.Output | Should -Match ([regex]::Escape("result: $State"))
            }
        }

        It 'fails when every job failed' {
            if (!$script:BashAvailable)
            {
                Set-ItResult -Skipped -Because 'bash is not available on this machine'
                return
            }
            $Results = @{}
            $script:EnvNames | ForEach-Object { $Results[$_] = 'failure' }
            $Run = Invoke-MergeChecksScript -Step $script:Step -Results $Results
            $Run.ExitCode | Should -Be 1
        }

        It 'fails when a result is missing' {
            if (!$script:BashAvailable)
            {
                Set-ItResult -Skipped -Because 'bash is not available on this machine'
                return
            }
            $Results = @{}
            $script:EnvNames | ForEach-Object { $Results[$_] = 'success' }
            $Results[$script:EnvNames[0]] = $null
            $Run = Invoke-MergeChecksScript -Step $script:Step -Results $Results
            $Run.ExitCode | Should -Be 1
        }
    }
}
