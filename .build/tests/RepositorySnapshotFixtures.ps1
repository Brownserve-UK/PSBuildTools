#Requires -Version 6.0

$script:FixtureNugetConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
'@

$script:FixtureToolManifestBase = @'
{
  "version": 1,
  "isRoot": true,
  "tools": {}
}
'@

$script:FixtureToolManifestWithPaket = @'
{
  "version": 1,
  "isRoot": true,
  "tools": {
    "paket": {
      "version": "8.0.3",
      "commands": [
        "paket"
      ]
    }
  }
}
'@

$script:FixtureLicenseText = @'
MIT License

Copyright (c) 2024 FIXTURE_OWNER

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'@

function Get-RepositorySnapshotFixtures
{
    [CmdletBinding()]
    param ()

    $ModuleInfo = @{
        Name        = 'Brownserve.TestModule'
        Description = 'A test module used for repository snapshot testing.'
        GUID        = '11111111-1111-1111-1111-111111111111'
        Tags        = @('test', 'powershell')
    }
    $PSCommonModuleInfo = @{
        Name        = 'Brownserve.PSCommon'
        Description = 'Foundational utilities for Brownserve PowerShell modules.'
        GUID        = '22222222-2222-2222-2222-222222222222'
        Tags        = @('brownserve', 'powershell', 'common')
    }

    return @(
        @{
            CaseName    = 'PowerShellModule'
            ProjectType = 'PowerShellModule'
            RepoName    = 'test-powershell-module'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $ModuleInfo
        },
        @{
            CaseName    = 'PowerShellModule_PSCommon'
            ProjectType = 'PowerShellModule'
            RepoName    = 'PSCommon'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $PSCommonModuleInfo
        },
        @{
            CaseName    = 'BrownservePSTools'
            ProjectType = 'BrownservePSTools'
            RepoName    = 'PSTools'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $ModuleInfo
        },
        @{
            CaseName    = 'WebApp'
            ProjectType = 'WebApp'
            RepoName    = 'test-web-app'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $null
        },
        @{
            CaseName    = 'RustApp'
            ProjectType = 'RustApp'
            RepoName    = 'test-rust-app'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $null
        },
        @{
            CaseName    = 'bsdev'
            ProjectType = 'bsdev'
            RepoName    = 'bsdev'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $null
        },
        @{
            CaseName    = 'SkillsRepo'
            ProjectType = 'SkillsRepo'
            RepoName    = 'test-skills-repo'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $null
        },
        @{
            CaseName    = 'Generic'
            ProjectType = 'Generic'
            RepoName    = 'test-generic-repo'
            Owner       = 'Brownserve-UK'
            ModuleInfo  = $null
        }
    )
}

function Set-RepositorySnapshotMocks
{
    [CmdletBinding()]
    param ()

    Mock Assert-Command -ModuleName Brownserve.PSBuildTools { }

    Mock Get-BrownserveLoadedModuleVersion -ModuleName Brownserve.PSBuildTools {
        param($Name)
        switch ($Name)
        {
            'Brownserve.PSCommon' { return '1.2.3' }
            'Brownserve.PSSourceControl' { return '2.3.4' }
            'Brownserve.PSBuildTools' { return '3.4.5' }
            default { throw "Unexpected module name '$Name'" }
        }
    }

    if (!(Get-Command 'dotnet' -ErrorAction SilentlyContinue))
    {
        InModuleScope Brownserve.PSBuildTools {
            function script:dotnet { }
        }
    }
    Mock dotnet -ModuleName Brownserve.PSBuildTools {
        return '8.0.100'
    }

    Mock New-SPDXLicense -ModuleName Brownserve.PSBuildTools {
        param($LicenseType, $Owner, $Year, $Uri)
        return ($script:FixtureLicenseText -replace 'FIXTURE_OWNER', $Owner)
    }

    Mock Invoke-NativeCommand -ModuleName Brownserve.PSBuildTools {
        param($FilePath, $ArgumentList, $WorkingDirectory, $ExitCodes, $PassThru, $SuppressOutput)
        if ($ArgumentList -contains 'nugetconfig')
        {
            Set-Content -Path (Join-Path $WorkingDirectory 'nuget.config') -Value $script:FixtureNugetConfig -NoNewline
        }
        elseif ($ArgumentList -contains 'tool-manifest')
        {
            Set-Content -Path (Join-Path $WorkingDirectory 'dotnet-tools.json') -Value $script:FixtureToolManifestBase -NoNewline
        }
        elseif ($ArgumentList -contains 'install')
        {
            Set-Content -Path (Join-Path $WorkingDirectory 'dotnet-tools.json') -Value $script:FixtureToolManifestWithPaket -NoNewline
        }
    }
}

function Invoke-RepositorySnapshotCompare
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryPath,

        [Parameter(Mandatory = $true)]
        [string]
        $ProjectType,

        [Parameter(Mandatory = $true)]
        [string]
        $RepoName,

        [Parameter(Mandatory = $true)]
        [string]
        $Owner,

        [Parameter(Mandatory = $false)]
        [hashtable]
        $ModuleInfo
    )

    InModuleScope Brownserve.PSBuildTools -Parameters @{
        RepositoryPath = $RepositoryPath
        ProjectType    = $ProjectType
        RepoName       = $RepoName
        Owner          = $Owner
        ModuleInfoData = $ModuleInfo
    } {
        param($RepositoryPath, $ProjectType, $RepoName, $Owner, $ModuleInfoData)

        $ModuleInfoObject = $null
        if ($ModuleInfoData)
        {
            $ModuleInfoObject = [BrownservePowerShellModule]$ModuleInfoData
        }

        # Route every case through the v1 -> v2 migration function and the component resolver, exactly as
        # 'Update-BrownserveRepository' would for a legacy repository. This means the snapshots also cover
        # migration, not just component resolution.
        $Migrated = ConvertTo-BrownserveRepoComponentFromLegacyType `
            -RepositoryType $ProjectType `
            -ModuleInfo $ModuleInfoObject `
            -ErrorAction 'Stop'

        $CompareParams = @{
            RepositoryPath   = $RepositoryPath
            Components       = $Migrated.Components
            ComponentOptions = $Migrated.ComponentOptions
            RepoName         = $RepoName
            Owner            = $Owner
            ErrorAction      = 'Stop'
        }

        Compare-BrownserveRepository @CompareParams
    }
}

function Get-RepositorySnapshotRelativePath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $BasePath,

        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    ([System.IO.Path]::GetRelativePath($BasePath, $Path)) -replace '\\', '/'
}
