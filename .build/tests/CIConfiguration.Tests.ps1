#requires -Modules Pester

BeforeAll {
    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

    $YamlModule = Get-ChildItem -Path (Join-Path $global:BrownserveRepoNugetPackagesDirectory 'powershell-yaml') -Filter 'powershell-yaml.psd1' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$YamlModule)
    {
        throw "The powershell-yaml module was not found under '$global:BrownserveRepoNugetPackagesDirectory'. Run _init.ps1 (or Save-Module powershell-yaml into that directory) before running this test."
    }
    Import-Module $YamlModule.FullName -Force -Verbose:$false

    $script:CoreGitHubData = InModuleScope Brownserve.PSBuildTools {
        (Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop')['Core'].Data.GitHubActions
    }

    function New-TestModuleInfo
    {
        InModuleScope Brownserve.PSBuildTools {
            [BrownservePowerShellModule]@{
                Name        = 'Brownserve.TestModule'
                Description = 'A test module used for CI configuration testing.'
                GUID        = '11111111-1111-1111-1111-111111111111'
                Tags        = @('test')
            }
        }
    }

    function Get-CIShape
    {
        param ($Name)
        switch ($Name)
        {
            'bsdev' { return @{ Components = @('RustBinary', 'ContainerImage'); ComponentOptions = @{ ContainerImage = @{ Context = 'image' } } } }
            'RustBinary' { return @{ Components = @('RustBinary'); ComponentOptions = @{} } }
            'ContainerImage' { return @{ Components = @('ContainerImage'); ComponentOptions = @{} } }
            'PowerShellModule' { return @{ Components = @('PowerShellModule'); ComponentOptions = @{ PowerShellModule = @{ ModuleInfo = (New-TestModuleInfo) } } } }
            'PowerShellModuleMkDocs' { return @{ Components = @('PowerShellModule', 'MkDocs'); ComponentOptions = @{ PowerShellModule = @{ ModuleInfo = (New-TestModuleInfo) } } } }
            'NuGetPackage' { return @{ Components = @('NuGetPackage'); ComponentOptions = @{ NuGetPackage = @{ PackageId = 'Brownserve.TestPackage'; PackageDescription = 'A test package' } } } }
            'DirectoryArchive' { return @{ Components = @('DirectoryArchive'); ComponentOptions = @{} } }
            'DirectoryArchiveAstro' { return @{ Components = @('DirectoryArchive', 'AstroDocs'); ComponentOptions = @{} } }
            'Mixed' { return @{ Components = @('RustBinary', 'PowerShellModule'); ComponentOptions = @{ PowerShellModule = @{ ModuleInfo = (New-TestModuleInfo) } } } }
        }
    }

    function Get-CIWorkflowSet
    {
        param ($Shape, $ComponentOptions, $RepoName = 'test-repo')
        $Params = Get-CIShape -Name $Shape
        if ($ComponentOptions)
        {
            $Params.ComponentOptions = $ComponentOptions
        }
        $Files = New-BrownserveCIConfiguration -Provider GitHubActions -Components $Params.Components -ComponentOptions $Params.ComponentOptions -RepoName $RepoName
        $Set = @{}
        foreach ($File in $Files)
        {
            $Set[[System.IO.Path]::GetFileName($File.Path)] = [pscustomobject]@{
                Path    = $File.Path
                Content = $File.Content
                Yaml    = ConvertFrom-Yaml $File.Content -Ordered
            }
        }
        return $Set
    }

    function ConvertTo-PermissionText
    {
        param ($Permissions)
        return (($Permissions.Keys | Sort-Object | ForEach-Object { "${_}: $($Permissions[$_])" }) -join '; ')
    }
}

Describe 'New-BrownserveCIConfiguration' {
    Context 'files returned' {
        It 'returns the five workflows with relative paths for a repository with ReleaseLifecycle' {
            $Set = Get-CIWorkflowSet -Shape 'RustBinary'
            $Set.Keys | Sort-Object | Should -Be @('builds.yaml', 'label-pr.yaml', 'release.yaml', 'stage-release.yaml')
            $Set['builds.yaml'].Path | Should -Be '.github/workflows/builds.yaml'
        }

        It 'returns nothing for a Core only repository' {
            $Files = @(New-BrownserveCIConfiguration -Provider GitHubActions -Components @() -RepoName 'test-repo')
            $Files.Count | Should -Be 0
        }

        It 'ends every file with a single newline and never uses CRLF' {
            $Set = Get-CIWorkflowSet -Shape 'bsdev'
            foreach ($Workflow in $Set.Values)
            {
                $Workflow.Content | Should -Match '[^\n]\n\z'
                $Workflow.Content | Should -Not -Match "`r"
            }
        }
    }

    Context 'provider' {
        It 'throws that TeamCity is not implemented' {
            { New-BrownserveCIConfiguration -Provider TeamCity -Components @('RustBinary') -RepoName 'test-repo' } | Should -Throw '*TeamCity*not implemented*'
        }

        It 'throws for an unknown component' {
            { New-BrownserveCIConfiguration -Provider GitHubActions -Components @('Nope') -RepoName 'test-repo' } | Should -Throw '*Unknown component*'
        }
    }

    Context 'job selection' {
        It 'gives a bsdev shaped repository one scoped job per check target' {
            $Jobs = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs
            @($Jobs.Keys | Where-Object { $_ -ne 'merge-checks' }) | Should -Be @('rust-binary', 'container-image')
            $Jobs['rust-binary'].with['build-task'] | Should -Be 'RustBinary.Check'
            $Jobs['container-image'].with['build-task'] | Should -Be 'ContainerImage.Check'
        }

        It 'gives <Shape> a single build job running BuildTestAndCheck on ubuntu' -ForEach @(
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'PowerShellModuleMkDocs' }
            @{ Shape = 'NuGetPackage' }
            @{ Shape = 'DirectoryArchive' }
            @{ Shape = 'DirectoryArchiveAstro' }
        ) {
            $Jobs = (Get-CIWorkflowSet -Shape $Shape)['builds.yaml'].Yaml.jobs
            @($Jobs.Keys | Where-Object { $_ -ne 'merge-checks' }) | Should -Be @('build')
            $Jobs['build'].with['build-task'] | Should -Be 'BuildTestAndCheck'
            $Jobs['build'].with['os-matrix'] | Should -Be '["ubuntu-latest"]'
        }

        It 'throws naming the components when the shape mixes check targets with other build work' {
            { Get-CIWorkflowSet -Shape 'Mixed' } | Should -Throw '*RustBinary*PowerShellModule*'
        }

        It 'calls the pinned pr-build workflow with the repo name' {
            $Jobs = (Get-CIWorkflowSet -Shape 'bsdev' -RepoName 'bsdev')['builds.yaml'].Yaml.jobs
            $Jobs['rust-binary'].with['repo-name'] | Should -Be 'bsdev'
            $Jobs['rust-binary'].uses | Should -Match 'brownserve-pr-build\.yaml@'
        }
    }

    Context 'Rust runners and matrices' {
        It 'maps the default targets to their runners for the check job' {
            $With = (Get-CIWorkflowSet -Shape 'RustBinary')['builds.yaml'].Yaml.jobs['rust-binary'].with
            ($With['os-matrix'] | ConvertFrom-Json) | Should -Be @('ubuntu-latest', 'windows-latest', 'macos-latest')
        }

        It 'keeps target order in the check matrix' {
            $Options = @{ RustBinary = @{ Targets = @('aarch64-apple-darwin', 'x86_64-unknown-linux-gnu') } }
            $With = (Get-CIWorkflowSet -Shape 'RustBinary' -ComponentOptions $Options)['builds.yaml'].Yaml.jobs['rust-binary'].with
            ($With['os-matrix'] | ConvertFrom-Json) | Should -Be @('macos-latest', 'ubuntu-latest')
        }

        It 'dedupes runners in the check matrix' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Definitions['RustBinary'].Data.GitHubActions.Runners['aarch64-unknown-linux-gnu'] = 'ubuntu-latest'
                $Runners = @(Get-BrownserveGitHubRunner -Targets @('x86_64-unknown-linux-gnu', 'aarch64-unknown-linux-gnu', 'x86_64-pc-windows-msvc') -Component 'RustBinary' -ComponentDefinitions $Definitions)
                $Runners | Should -Be @('ubuntu-latest', 'windows-latest')
            }
        }

        It 'passes one package matrix entry per target with the RustBinary.Package task' {
            $With = (Get-CIWorkflowSet -Shape 'RustBinary')['release.yaml'].Yaml.jobs['release'].with
            $Matrix = $With['package-matrix'] | ConvertFrom-Json
            @($Matrix).Count | Should -Be 3
            $Matrix[0].os | Should -Be 'ubuntu-latest'
            $Matrix[0].target | Should -Be 'x86_64-unknown-linux-gnu'
            $Matrix[1].os | Should -Be 'windows-latest'
            $Matrix[1].target | Should -Be 'x86_64-pc-windows-msvc'
            $Matrix[2].os | Should -Be 'macos-latest'
            $Matrix[2].target | Should -Be 'aarch64-apple-darwin'
            $With['package-build-task'] | Should -Be 'RustBinary.Package'
        }

        It 'produces no package matrix for <Shape>' -ForEach @(
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'ContainerImage' }
            @{ Shape = 'NuGetPackage' }
            @{ Shape = 'DirectoryArchiveAstro' }
        ) {
            $With = (Get-CIWorkflowSet -Shape $Shape)['release.yaml'].Yaml.jobs['release'].with
            $With.Keys | Should -Not -Contain 'package-matrix'
            $With.Keys | Should -Not -Contain 'package-build-task'
        }

        It 'throws naming the triple and the map location for an unknown target' {
            $Options = @{ RustBinary = @{ Targets = @('riscv64gc-unknown-linux-gnu') } }
            { Get-CIWorkflowSet -Shape 'RustBinary' -ComponentOptions $Options } | Should -Throw '*riscv64gc-unknown-linux-gnu*RustBinary/component.psd1*'
        }
    }

    Context 'change patterns' {
        It 'adds the common patterns to every job' {
            $Jobs = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs
            foreach ($Name in @('rust-binary', 'container-image'))
            {
                $Jobs[$Name].with['change-pattern'] | Should -BeLike '^(*|\.build/|\.config/|nuget\.config$)'
            }
        }

        It 'scopes the Rust job to Rust files and build files' {
            $Pattern = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs['rust-binary'].with['change-pattern']
            $Pattern | Should -Be '^(Cargo\.toml$|Cargo\.lock$|.*\.rs$|\.build/|\.config/|nuget\.config$)'
            'src/main.rs' | Should -Match $Pattern
            '.build/build.ps1' | Should -Match $Pattern
            'image/Dockerfile' | Should -Not -Match $Pattern
        }

        It 'scopes the container job to the image directory for a custom context' {
            $Pattern = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs['container-image'].with['change-pattern']
            $Pattern | Should -Be '^(image/|\.build/|\.config/|nuget\.config$)'
            'src/main.rs' | Should -Not -Match $Pattern
        }

        It 'scopes the container job to the source files for a root context' {
            $Pattern = (Get-CIWorkflowSet -Shape 'ContainerImage')['builds.yaml'].Yaml.jobs['container-image'].with['change-pattern']
            $Pattern | Should -Be '^(src/|Dockerfile|package\.json$|\.build/|\.config/|nuget\.config$)'
        }

        It 'unions every enabled component for the single job' {
            $Pattern = (Get-CIWorkflowSet -Shape 'DirectoryArchiveAstro')['builds.yaml'].Yaml.jobs['build'].with['change-pattern']
            $Pattern | Should -Be '^(skills/|pages/|\.build/|\.config/|nuget\.config$)'
        }

        It 'uses the module and docs paths for a PowerShell module' {
            $Pattern = (Get-CIWorkflowSet -Shape 'PowerShellModuleMkDocs')['builds.yaml'].Yaml.jobs['build'].with['change-pattern']
            $Pattern | Should -Be '^(module/|pages/Cmdlet reference/|\.build/|\.config/|nuget\.config$)'
        }

        It 'escapes the archive path' {
            $Options = @{ DirectoryArchive = @{ Path = 'my.skills' } }
            $Pattern = (Get-CIWorkflowSet -Shape 'DirectoryArchive' -ComponentOptions $Options)['builds.yaml'].Yaml.jobs['build'].with['change-pattern']
            $Pattern | Should -Be '^(my\.skills/|\.build/|\.config/|nuget\.config$)'
            'myXskills/a.md' | Should -Not -Match $Pattern
        }

        It 'uses the tasks directory for a NuGet package' {
            $Pattern = (Get-CIWorkflowSet -Shape 'NuGetPackage')['builds.yaml'].Yaml.jobs['build'].with['change-pattern']
            $Pattern | Should -Be '^(tasks/|\.build/|\.config/|nuget\.config$)'
        }
    }

    Context 'toolchains' {
        It 'sets only rust on the Rust check job' {
            $With = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs['rust-binary'].with
            $With['rust'] | Should -BeTrue
            $With.Keys | Should -Not -Contain 'node'
            $With.Keys | Should -Not -Contain 'mono'
        }

        It 'sets no toolchain input on the container check job' {
            $With = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs['container-image'].with
            $With.Keys | Should -Not -Contain 'rust'
            $With.Keys | Should -Not -Contain 'node'
            $With.Keys | Should -Not -Contain 'mono'
        }

        It 'sets node on the single job when AstroDocs is enabled' {
            $With = (Get-CIWorkflowSet -Shape 'DirectoryArchiveAstro')['builds.yaml'].Yaml.jobs['build'].with
            $With['node'] | Should -BeTrue
        }

        It 'sets no toolchain on the PowerShell module build job' {
            $With = (Get-CIWorkflowSet -Shape 'PowerShellModule')['builds.yaml'].Yaml.jobs['build'].with
            $With.Keys | Should -Not -Contain 'mono'
        }

        It 'sets rust when staging a Rust repository and nothing for a PowerShell module' {
            (Get-CIWorkflowSet -Shape 'bsdev')['stage-release.yaml'].Yaml.jobs['stage-release'].with['rust'] | Should -BeTrue
            (Get-CIWorkflowSet -Shape 'PowerShellModule')['stage-release.yaml'].Yaml.jobs['stage-release'].with.Keys | Should -Not -Contain 'rust'
        }

        It 'sets mono on the release for <Shape>' -ForEach @(
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'NuGetPackage' }
        ) {
            (Get-CIWorkflowSet -Shape $Shape)['release.yaml'].Yaml.jobs['release'].with['mono'] | Should -BeTrue
        }

        It 'needs no cargo on the bsdev release because it collects archives' {
            $With = (Get-CIWorkflowSet -Shape 'bsdev')['release.yaml'].Yaml.jobs['release'].with
            $With.Keys | Should -Not -Contain 'rust'
            $With.Keys | Should -Not -Contain 'mono'
        }

        It 'sets node on the release when AstroDocs is enabled' {
            $With = (Get-CIWorkflowSet -Shape 'DirectoryArchiveAstro')['release.yaml'].Yaml.jobs['release'].with
            $With['node'] | Should -BeTrue
        }

        It 'sets no node input on the release for <Shape>' -ForEach @(
            @{ Shape = 'bsdev' }
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'DirectoryArchive' }
        ) {
            (Get-CIWorkflowSet -Shape $Shape)['release.yaml'].Yaml.jobs['release'].with.Keys | Should -Not -Contain 'node'
        }

        It 'declares the release toolchain inputs in the order the workflow does' {
            $script:CoreGitHubData.Workflows['Release'].ToolchainInputs | Should -Be @('node', 'mono')
        }

        It 'keeps no runner provided tools data on any workflow' {
            foreach ($Workflow in $script:CoreGitHubData.Workflows.Values)
            {
                $Workflow.Keys | Should -Not -Contain 'RunnerProvidedTools'
            }
        }

        It 'throws for npm on a workflow with no node input' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Npm = [pscustomobject]@{ Component = 'AstroDocs'; Tools = @('npm'); Platform = $null }
                { Get-BrownserveGitHubToolchainInput -Requirements @($Npm) -Runners @('ubuntu-latest') -Workflow 'StageRelease' -ComponentDefinitions $Definitions } | Should -Throw '*npm*AstroDocs*brownserve-stage-release.yaml*'
            }
        }

        It 'allows docker only when every runner is ubuntu-latest' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Docker = [pscustomobject]@{ Component = 'ContainerImage'; Tools = @('docker'); Platform = $null }
                @(Get-BrownserveGitHubToolchainInput -Requirements @($Docker) -Runners @('ubuntu-latest') -Workflow 'PullRequestBuild' -ComponentDefinitions $Definitions).Count | Should -Be 0
                { Get-BrownserveGitHubToolchainInput -Requirements @($Docker) -Runners @('ubuntu-latest', 'windows-latest') -Workflow 'PullRequestBuild' -ComponentDefinitions $Definitions } | Should -Throw '*docker*ContainerImage*windows-latest*'
            }
        }

        It 'throws naming the tool, component and workflow for a toolchain the workflow has no input for' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Terraform = [pscustomobject]@{ Component = 'Example'; Tools = @('terraform'); Platform = $null }
                { Get-BrownserveGitHubToolchainInput -Requirements @($Terraform) -Runners @('ubuntu-latest') -Workflow 'PullRequestBuild' -ComponentDefinitions $Definitions } | Should -Throw '*terraform*Example*brownserve-pr-build.yaml*'
                $Cargo = [pscustomobject]@{ Component = 'RustBinary'; Tools = @('cargo'); Platform = $null }
                { Get-BrownserveGitHubToolchainInput -Requirements @($Cargo) -Runners @('ubuntu-latest') -Workflow 'Release' -ComponentDefinitions $Definitions } | Should -Throw '*cargo*RustBinary*brownserve-release.yaml*'
            }
        }

        It 'ignores a requirement whose platform never applies to the runners' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Mono = [pscustomobject]@{ Component = 'PowerShellModule'; Tools = @('mono'); Platform = 'Windows' }
                @(Get-BrownserveGitHubToolchainInput -Requirements @($Mono) -Runners @('ubuntu-latest') -Workflow 'Release' -ComponentDefinitions $Definitions).Count | Should -Be 0
            }
        }

        It 'refuses a platform specific requirement when only some runners match' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Mono = [pscustomobject]@{ Component = 'PowerShellModule'; Tools = @('mono'); Platform = 'NonWindows' }
                { Get-BrownserveGitHubToolchainInput -Requirements @($Mono) -Runners @('ubuntu-latest', 'windows-latest') -Workflow 'PullRequestBuild' -ComponentDefinitions $Definitions } | Should -Throw '*mono*only applies to some*'
            }
        }
    }

    Context 'permissions' {
        It 'grants the pr-build jobs exactly what the called workflow declares' {
            $Jobs = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs
            foreach ($Name in @('rust-binary', 'container-image'))
            {
                ConvertTo-PermissionText $Jobs[$Name].permissions | Should -Be 'contents: read; pull-requests: read'
            }
        }

        It 'gives merge-checks no permissions' {
            $Job = (Get-CIWorkflowSet -Shape 'bsdev')['builds.yaml'].Yaml.jobs['merge-checks']
            $Job.permissions.Count | Should -Be 0
        }

        It 'grants stage-release contents read' {
            $Set = Get-CIWorkflowSet -Shape 'bsdev'
            ConvertTo-PermissionText $Set['stage-release.yaml'].Yaml.jobs['stage-release'].permissions | Should -Be 'contents: read'
        }

        It 'grants release contents read and packages write for <Shape>, which publishes to GHCR' -ForEach @(
            @{ Shape = 'bsdev' }
            @{ Shape = 'ContainerImage' }
        ) {
            $Set = Get-CIWorkflowSet -Shape $Shape
            ConvertTo-PermissionText $Set['release.yaml'].Yaml.jobs['release'].permissions | Should -Be 'contents: read; packages: write'
        }

        It 'grants release only contents read for <Shape>' -ForEach @(
            @{ Shape = 'RustBinary' }
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'NuGetPackage' }
            @{ Shape = 'DirectoryArchive' }
            @{ Shape = 'DirectoryArchiveAstro' }
        ) {
            $Set = Get-CIWorkflowSet -Shape $Shape
            ConvertTo-PermissionText $Set['release.yaml'].Yaml.jobs['release'].permissions | Should -Be 'contents: read'
        }

        It 'grants no packages write when ContainerImage only publishes to DockerHub' {
            $Set = Get-CIWorkflowSet -Shape 'ContainerImage' -ComponentOptions @{ ContainerImage = @{ Registries = @('DockerHub') } }
            ConvertTo-PermissionText $Set['release.yaml'].Yaml.jobs['release'].permissions | Should -Be 'contents: read'
            $Set['release.yaml'].Yaml.jobs['release'].secrets.Keys | Should -Contain 'dockerhub-token'
        }

        It 'grants packages write and no DockerHub secrets when ContainerImage only publishes to GHCR' {
            $Set = Get-CIWorkflowSet -Shape 'ContainerImage' -ComponentOptions @{ ContainerImage = @{ Registries = @('GHCR') } }
            ConvertTo-PermissionText $Set['release.yaml'].Yaml.jobs['release'].permissions | Should -Be 'contents: read; packages: write'
            $Set['release.yaml'].Yaml.jobs['release'].secrets.Keys | Should -Not -Contain 'dockerhub-token'
            $Set['release.yaml'].Yaml.jobs['release'].secrets.Keys | Should -Not -Contain 'dockerhub-username'
            $Set['release.yaml'].Yaml['on'].workflow_dispatch.inputs.publish_to.default | Should -Not -Match 'DockerHub'
        }

        It 'lists each release permission once' {
            InModuleScope Brownserve.PSBuildTools {
                $Definitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
                $Definitions['ContainerImage'].Data.CI.PublishPermissions['DockerHub'] = @('WritePackages')
                $Resolved = Resolve-BrownserveRepoComponent -Name @('ContainerImage') -Options @{} -ErrorAction 'Stop'
                $Plan = Get-BrownserveCIPlan -ResolvedComponents $Resolved -ComponentDefinitions $Definitions -RepoName 'test-repo'
                $Plan.Release.Permissions | Should -Be @('ReadContents', 'WritePackages')
            }
        }

        It 'grants deploy-docs contents write' {
            $Set = Get-CIWorkflowSet -Shape 'PowerShellModuleMkDocs'
            ConvertTo-PermissionText $Set['release.yaml'].Yaml.jobs['deploy-docs'].permissions | Should -Be 'contents: write'
        }

        It 'grants label-pr issues and pull request write' {
            $Set = Get-CIWorkflowSet -Shape 'bsdev'
            ConvertTo-PermissionText $Set['label-pr.yaml'].Yaml.jobs['label-pr'].permissions | Should -Be 'issues: write; pull-requests: write'
        }

        It 'keeps an empty top level permissions block in <File>' -ForEach @(
            @{ File = 'builds.yaml' }
            @{ File = 'stage-release.yaml' }
            @{ File = 'release.yaml' }
            @{ File = 'label-pr.yaml' }
        ) {
            $Yaml = (Get-CIWorkflowSet -Shape 'bsdev')[$File].Yaml
            $Yaml.permissions.Count | Should -Be 0
        }
    }

    Context 'secrets' {
        It 'maps only the app credentials for staging' {
            $Secrets = (Get-CIWorkflowSet -Shape 'bsdev')['stage-release.yaml'].Yaml.jobs['stage-release'].secrets
            @($Secrets.Keys) | Should -Be @('app-id', 'app-private-key')
            $Secrets['app-id'] | Should -Be '${{ secrets.BROWNSERVE_CI_APP_ID }}'
            $Secrets['app-private-key'] | Should -Be '${{ secrets.BROWNSERVE_CI_APP_PRIVATE_KEY }}'
        }

        It 'maps only the DockerHub secrets for a bsdev shaped release' {
            $Secrets = (Get-CIWorkflowSet -Shape 'bsdev')['release.yaml'].Yaml.jobs['release'].secrets
            @($Secrets.Keys) | Should -Be @('app-id', 'app-private-key', 'slack-webhook', 'dockerhub-username', 'dockerhub-token')
            $Secrets['slack-webhook'] | Should -Be '${{ secrets.SLACK_WEBHOOK_BUILD }}'
            $Secrets['dockerhub-username'] | Should -Be '${{ secrets.DOCKERHUB_USERNAME }}'
            $Secrets['dockerhub-token'] | Should -Be '${{ secrets.DOCKERHUB_TOKEN }}'
        }

        It 'maps the NuGet and PSGallery keys for a PowerShell module' {
            $Secrets = (Get-CIWorkflowSet -Shape 'PowerShellModule')['release.yaml'].Yaml.jobs['release'].secrets
            @($Secrets.Keys) | Should -Be @('app-id', 'app-private-key', 'slack-webhook', 'nuget-api-key', 'psgallery-api-key')
            $Secrets['nuget-api-key'] | Should -Be '${{ secrets.NUGET_API_KEY }}'
            $Secrets['psgallery-api-key'] | Should -Be '${{ secrets.POWERSHELL_GALLERY_API_KEY }}'
        }

        It 'maps only the NuGet key for a NuGet package' {
            $Secrets = (Get-CIWorkflowSet -Shape 'NuGetPackage')['release.yaml'].Yaml.jobs['release'].secrets
            @($Secrets.Keys) | Should -Be @('app-id', 'app-private-key', 'slack-webhook', 'nuget-api-key')
        }

        It 'maps no optional secrets for a directory archive' {
            $Secrets = (Get-CIWorkflowSet -Shape 'DirectoryArchive')['release.yaml'].Yaml.jobs['release'].secrets
            @($Secrets.Keys) | Should -Be @('app-id', 'app-private-key', 'slack-webhook')
        }

        It 'never inherits secrets in <Shape>' -ForEach @(
            @{ Shape = 'bsdev' }
            @{ Shape = 'PowerShellModuleMkDocs' }
        ) {
            foreach ($Workflow in (Get-CIWorkflowSet -Shape $Shape).Values)
            {
                $Workflow.Content | Should -Not -Match 'secrets:\s*inherit'
            }
        }
    }

    Context 'release inputs' {
        It 'defaults publish_to to the union of publish values without CustomNugetFeeds for <Shape>' -ForEach @(
            @{ Shape = 'PowerShellModule'; Expected = '"nuget", "PSGallery", "GitHub"' }
            @{ Shape = 'NuGetPackage'; Expected = '"nuget", "GitHub"' }
            @{ Shape = 'bsdev'; Expected = '"GitHub", "DockerHub", "GHCR"' }
            @{ Shape = 'DirectoryArchive'; Expected = '"GitHub"' }
        ) {
            $Yaml = (Get-CIWorkflowSet -Shape $Shape)['release.yaml'].Yaml
            $Yaml['on'].workflow_dispatch.inputs.publish_to.default | Should -Be $Expected
        }

        It 'passes publish_to through to the reusable workflow' {
            $With = (Get-CIWorkflowSet -Shape 'PowerShellModule')['release.yaml'].Yaml.jobs['release'].with
            $With['publish-to'] | Should -Be '${{ inputs.publish_to }}'
        }

        It 'keeps the release_type choice input on stage-release' {
            $Input = (Get-CIWorkflowSet -Shape 'bsdev')['stage-release.yaml'].Yaml['on'].workflow_dispatch.inputs.release_type
            $Input.type | Should -Be 'choice'
            $Input.default | Should -Be 'minor'
            @($Input.options) | Should -Be @('major', 'minor', 'patch')
            (Get-CIWorkflowSet -Shape 'bsdev')['stage-release.yaml'].Yaml.jobs['stage-release'].with['release-type'] | Should -Be '${{ inputs.release_type }}'
        }
    }

    Context 'documentation deployment' {
        It 'adds an mkdocs deploy-docs job that needs release when MkDocs is enabled' {
            $Jobs = (Get-CIWorkflowSet -Shape 'PowerShellModuleMkDocs')['release.yaml'].Yaml.jobs
            $Jobs['deploy-docs'].needs | Should -Be 'release'
            $Jobs['deploy-docs'].uses | Should -Match 'brownserve-deploy-docs\.yaml@'
            $Jobs['deploy-docs'].with['engine'] | Should -Be 'mkdocs'
            $Jobs['deploy-docs'].with.Keys | Should -Not -Contain 'docs-path'
        }

        It 'adds an astro deploy-docs job with the docs path when AstroDocs is enabled' {
            $Jobs = (Get-CIWorkflowSet -Shape 'DirectoryArchiveAstro')['release.yaml'].Yaml.jobs
            $Jobs['deploy-docs'].needs | Should -Be 'release'
            $Jobs['deploy-docs'].with['engine'] | Should -Be 'astro'
            $Jobs['deploy-docs'].with['docs-path'] | Should -Be 'pages'
        }

        It 'has no deploy-docs job for <Shape>' -ForEach @(
            @{ Shape = 'PowerShellModule' }
            @{ Shape = 'bsdev' }
            @{ Shape = 'NuGetPackage' }
        ) {
            (Get-CIWorkflowSet -Shape $Shape)['release.yaml'].Yaml.jobs.Keys | Should -Not -Contain 'deploy-docs'
        }
    }

    Context 'pins' {
        It 'pins every reusable workflow to the Core commit with a version comment' {
            $Pattern = '^Brownserve-UK/actions/\.github/workflows/brownserve-[a-z-]+\.yaml@' + $script:CoreGitHubData.ActionsCommit + ' # ' + [regex]::Escape($script:CoreGitHubData.ActionsVersion) + '$'
            $Set = Get-CIWorkflowSet -Shape 'PowerShellModuleMkDocs'
            $Count = 0
            foreach ($Workflow in $Set.Values)
            {
                foreach ($Line in ($Workflow.Content -split "`n" | Where-Object { $_ -match '^\s+uses:' }))
                {
                    ($Line -replace '^\s+uses:\s+', '') | Should -Match $Pattern
                    $Count++
                }
            }
            $Count | Should -BeGreaterThan 4
        }

        It 'uses the v0.2.0 commit with a v0.2.0 comment' {
            $script:CoreGitHubData.ActionsVersion | Should -Be 'v0.2.0'
            $script:CoreGitHubData.ActionsCommit | Should -Be '28d69596e4bcf98b0fe7f260c8ea2486265cd03a'
            $Set = Get-CIWorkflowSet -Shape 'bsdev'
            $Line = $Set['release.yaml'].Content -split "`n" | Where-Object { $_ -match '^\s+uses:' } | Select-Object -First 1
            $Line | Should -Match '@28d69596e4bcf98b0fe7f260c8ea2486265cd03a # v0\.2\.0$'
        }

        It 'holds a full length commit SHA and a semantic version in the Core data' {
            $script:CoreGitHubData.ActionsCommit | Should -Match '^[0-9a-f]{40}$'
            $script:CoreGitHubData.ActionsVersion | Should -Match '^v\d+\.\d+\.\d+$'
        }
    }
}
