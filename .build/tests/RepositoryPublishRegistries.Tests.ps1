#requires -Modules Pester

. (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

Describe 'ContainerImage registries' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'RepositorySnapshotFixtures.ps1')

        Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
        Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

        function script:Invoke-RegistryCompare
        {
            param ([string]$RepositoryPath, [hashtable]$ComponentOptions = @{})

            InModuleScope Brownserve.PSBuildTools -Parameters @{ RepositoryPath = $RepositoryPath; ComponentOptions = $ComponentOptions } {
                param($RepositoryPath, $ComponentOptions)
                Compare-BrownserveRepository `
                    -RepositoryPath $RepositoryPath `
                    -Components @('ContainerImage') `
                    -ComponentOptions $ComponentOptions `
                    -RepoName 'test-repo' `
                    -ErrorAction 'Stop'
            }
        }

        function script:Get-RenderedFile
        {
            param ($Result, [string]$RelativePath)

            $Match = $Result.MissingFiles | Where-Object { $_.Path -like "*/$RelativePath" } | Select-Object -First 1
            return ($Match.Content -join "`n")
        }
    }

    BeforeEach {
        $script:RepositoryPath = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -Path $script:RepositoryPath -ItemType Directory -Force | Out-Null
        Set-RepositorySnapshotMocks
    }

    It 'publishes to GHCR only' {
        $Result = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath -ComponentOptions @{ ContainerImage = @{ Registries = @('GHCR') } }
        $BuildTasks = Get-RenderedFile -Result $Result -RelativePath '.build/tasks/build_tasks.ps1'
        $BuildTasks | Should -Match "\[ValidateSet\('GHCR'\)\]"
        $BuildTasks | Should -Match "\`$_ -in @\('GHCR'\)"
        $BuildTasks | Should -Not -Match "'DockerHub'"
        $Release = Get-RenderedFile -Result $Result -RelativePath '.github/workflows/release.yaml'
        $Release | Should -Match "default: '`"GHCR`"'"
        $Release | Should -Not -Match 'DOCKERHUB'
        $Release | Should -Match 'packages: write'
    }

    It 'publishes to DockerHub only' {
        $Result = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath -ComponentOptions @{ ContainerImage = @{ Registries = @('DockerHub') } }
        $BuildTasks = Get-RenderedFile -Result $Result -RelativePath '.build/tasks/build_tasks.ps1'
        $BuildTasks | Should -Match "\[ValidateSet\('DockerHub'\)\]"
        $BuildTasks | Should -Not -Match "'GHCR'"
        $Release = Get-RenderedFile -Result $Result -RelativePath '.github/workflows/release.yaml'
        $Release | Should -Match 'DOCKERHUB_TOKEN'
        $Release | Should -Not -Match 'packages: write'
    }

    It 'publishes to both registries by default' {
        $Default = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath
        $Explicit = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath -ComponentOptions @{ ContainerImage = @{ Registries = @('GHCR', 'DockerHub') } }
        (Get-RenderedFile -Result $Default -RelativePath '.build/tasks/build_tasks.ps1') | Should -Match "\[ValidateSet\('DockerHub', 'GHCR'\)\]"
        $Release = Get-RenderedFile -Result $Default -RelativePath '.github/workflows/release.yaml'
        $Release | Should -Match 'DOCKERHUB_TOKEN'
        $Release | Should -Match 'packages: write'
        (Get-RenderedFile -Result $Explicit -RelativePath '.github/workflows/release.yaml') | Should -Match 'DOCKERHUB_TOKEN'
    }

    It 'keeps the generated build script parameters the same whichever registries are chosen' {
        $Default = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath
        $Ghcr = Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath -ComponentOptions @{ ContainerImage = @{ Registries = @('GHCR') } }
        $Params = { param($Text) ($Text -split "`n" | Where-Object { $_ -match '^\s+\$[A-Za-z]+,?$' }) -join "`n" }
        & $Params (Get-RenderedFile -Result $Ghcr -RelativePath '.build/tasks/build_tasks.ps1') | Should -Be (& $Params (Get-RenderedFile -Result $Default -RelativePath '.build/tasks/build_tasks.ps1'))
    }

    It 'throws naming the component, option and allowed values for <Name>' -ForEach @(
        @{ Name = 'an empty list'; Value = @() }
        @{ Name = 'an unknown registry'; Value = @('GHCR', 'Quay') }
    ) {
        { Invoke-RegistryCompare -RepositoryPath $script:RepositoryPath -ComponentOptions @{ ContainerImage = @{ Registries = $Value } } } |
            Should -Throw "*'Registries' option of the ContainerImage component*'DockerHub', 'GHCR'*"
        Get-ChildItem -Path $script:RepositoryPath -Force | Should -BeNullOrEmpty
    }
}
