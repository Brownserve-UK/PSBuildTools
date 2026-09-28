#requires -Modules Pester

BeforeAll {
    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

    $script:PinnedTasksDir = Join-Path $Global:BrownserveRepoNugetPackagesDirectory 'Brownserve.PSBuildTasks' 'tasks'

    function Get-PinnedTaskFileParameterNames
    {
        param ($TaskFile, $TasksDir)
        $TaskFilePath = Join-Path $TasksDir $TaskFile
        if (!(Test-Path $TaskFilePath))
        {
            throw "The pinned task file '$TaskFilePath' was not found. Restore 'Brownserve.PSBuildTasks' via paket (or populate the test scratchpad's 'packages/Brownserve.PSBuildTasks/tasks/' with the pinned release) before running this test."
        }
        $Content = Get-Content -Path $TaskFilePath -Raw
        $Errors = $null
        $Tokens = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$Errors)
        if ($Errors.Count -gt 0)
        {
            throw "Failed to parse '$TaskFile': $($Errors[0].Message)"
        }
        $ParamBlock = $Ast.ParamBlock
        return @($ParamBlock.Parameters.Name.VariablePath.UserPath)
    }
}

Describe 'BuildTasks component contracts' {
    BeforeAll {
        $script:AllDefinitions = InModuleScope Brownserve.PSBuildTools { Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop' }
    }

    $ComponentNames = @('ReleaseLifecycle', 'PowerShellModule', 'RustBinary', 'ContainerImage', 'DirectoryArchive', 'NuGetPackage', 'AstroDocs')

    Context '<_>' -ForEach $ComponentNames {
        It 'declares parameter names matching the pinned task file''s param() block' {
            $ComponentName = $_
            $BuildTasksData = $script:AllDefinitions[$ComponentName].Data.BuildTasks
            $BuildTasksData | Should -Not -BeNullOrEmpty
            $DeclaredNames = @($BuildTasksData.Parameters | Sort-Object)
            $ActualNames = @(Get-PinnedTaskFileParameterNames -TaskFile $BuildTasksData.TaskFile -TasksDir $script:PinnedTasksDir | Sort-Object)
            $DeclaredNames | Should -Be $ActualNames
        }
    }
}

Describe 'Brownserve.PSBuildTasks pin' {
    It 'matches the version pinned in Core component data and in paket.dependencies' {
        $Definitions = InModuleScope Brownserve.PSBuildTools { Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop' }
        $CoreVersion = $Definitions['Core'].Data.PSBuildTasksVersion
        $CoreVersion | Should -Not -BeNullOrEmpty
        $PaketDependenciesPath = Join-Path $PSScriptRoot '..' '..' 'paket.dependencies'
        $PaketDependenciesContent = Get-Content $PaketDependenciesPath -Raw
        $PaketDependenciesContent | Should -Match ([regex]::Escape("nuget Brownserve.PSBuildTasks = $CoreVersion"))
    }

    It 'matches the restored package version, when the package exposes one' {
        $PackageRoot = Join-Path $Global:BrownserveRepoNugetPackagesDirectory 'Brownserve.PSBuildTasks'
        $NuspecPath = Get-ChildItem -Path $PackageRoot -Filter '*.nuspec' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (!$NuspecPath)
        {
            Set-ItResult -Skipped -Because 'the restored package does not expose a .nuspec, the pin test above is sufficient'
            return
        }
        $Definitions = InModuleScope Brownserve.PSBuildTools { Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop' }
        $CoreVersion = $Definitions['Core'].Data.PSBuildTasksVersion
        [xml]$Nuspec = Get-Content -Path $NuspecPath.FullName -Raw
        $Nuspec.package.metadata.version | Should -Be $CoreVersion
    }
}
