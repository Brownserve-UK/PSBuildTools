#requires -Modules Pester

BeforeAll {
    Remove-Module Brownserve.PSBuildTools -ErrorAction SilentlyContinue -Verbose:$false
    Join-Path $global:BrownserveBuiltModuleDirectory 'Brownserve.PSBuildTools.psd1' | Import-Module -Force -Verbose:$false

    function Get-BrownserveToolchainCheckText
    {
        param ($Content)
        $StartIndex = $Content.IndexOf('$RequiredToolchains = @(')
        if ($StartIndex -lt 0)
        {
            throw 'Could not find the toolchain check block start marker in the generated build.ps1.'
        }
        $EndMarker = '$BuildParams = @{'
        $EndMarkerIndex = $Content.IndexOf($EndMarker, $StartIndex)
        if ($EndMarkerIndex -lt 0)
        {
            throw 'Could not find the toolchain check block end marker in the generated build.ps1.'
        }
        $TryIndex = $Content.LastIndexOf('try', $EndMarkerIndex)
        return $Content.Substring($StartIndex, $TryIndex - $StartIndex)
    }

    function Invoke-BrownserveToolchainCheck
    {
        param ($BuildScriptContent, $Build, $ArchiveSourceDirectory, $AvailableTools = @())

        $ToolchainText = Get-BrownserveToolchainCheckText -Content $BuildScriptContent
        $ScriptText = @"
param(`$Build, `$ArchiveSourceDirectory, `$AvailableTools)
function Get-Command
{
    param(`$Name, `$ErrorAction)
    if (`$AvailableTools -contains `$Name)
    {
        return [pscustomobject]@{ Name = `$Name }
    }
    return `$null
}
$ToolchainText
return `$MissingTools
"@
        $ScriptBlock = [scriptblock]::Create($ScriptText)
        return & $ScriptBlock -Build $Build -ArchiveSourceDirectory $ArchiveSourceDirectory -AvailableTools $AvailableTools
    }

    function New-BrownserveTestBuildScript
    {
        param ($Components, $ComponentOptions = @{})
        InModuleScope Brownserve.PSBuildTools -Parameters @{ Components = $Components; ComponentOptions = $ComponentOptions } {
            param($Components, $ComponentOptions)
            $ComponentDefinitions = Get-BrownserveRepoComponentDefinition -ErrorAction 'Stop'
            $ResolvedComponents = Resolve-BrownserveRepoComponent -Name $Components -Options $ComponentOptions -ErrorAction 'Stop'
            New-BrownserveBuildScript -ResolvedComponents $ResolvedComponents -ComponentDefinitions $ComponentDefinitions -Owner 'Brownserve-UK' -RepoName 'test-repo'
        }
    }
}

Describe 'Generated build.ps1 toolchain checks' {
    It 'fails with a message naming the missing tool and its component' {
        $Content = New-BrownserveTestBuildScript -Components @('RustBinary')
        { Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'Build' -ArchiveSourceDirectory $null -AvailableTools @() } |
            Should -Throw '*cargo*RustBinary*'
    }

    It 'requires the union of tools for aggregate targets across components' {
        $Content = New-BrownserveTestBuildScript -Components @('RustBinary', 'ContainerImage')
        { Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'BuildTestAndCheck' -ArchiveSourceDirectory $null -AvailableTools @('cargo') } |
            Should -Throw '*docker*ContainerImage*'
        { Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'BuildTestAndCheck' -ArchiveSourceDirectory $null -AvailableTools @('docker') } |
            Should -Throw '*cargo*RustBinary*'
        $MissingTools = Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'BuildTestAndCheck' -ArchiveSourceDirectory $null -AvailableTools @('cargo', 'docker')
        $MissingTools.Count | Should -Be 0
    }

    It 'skips the cargo requirement in RustBinary collector mode' {
        $Content = New-BrownserveTestBuildScript -Components @('RustBinary')
        $MissingTools = Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'Release' -ArchiveSourceDirectory 'archives' -AvailableTools @()
        $MissingTools.Count | Should -Be 0
    }

    It 'requires no docker for StageRelease on a ContainerImage-only repository' {
        $Content = New-BrownserveTestBuildScript -Components @('ContainerImage')
        $MissingTools = Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'StageRelease' -ArchiveSourceDirectory $null -AvailableTools @()
        $MissingTools.Count | Should -Be 0
    }

    It 'passes for a target that needs nothing' {
        $Content = New-BrownserveTestBuildScript -Components @('DirectoryArchive')
        $MissingTools = Invoke-BrownserveToolchainCheck -BuildScriptContent $Content -Build 'Build' -ArchiveSourceDirectory $null -AvailableTools @()
        $MissingTools.Count | Should -Be 0
    }
}
