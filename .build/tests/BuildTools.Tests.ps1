#requires -Modules Pester
#.SYNOPSIS
#   Performs functional tests for PSBuildTools cmdlets
Describe 'Build tool cmdlets' {
    Context 'Format-NuGetPackageVersion' {
        It 'should return the version unchanged for SemVer 2.0.0 with no labels' {
            Format-NuGetPackageVersion -Version '1.2.3' | Should -Be '1.2.3'
        }
        It 'should return the version unchanged for SemVer 2.0.0 with pre-release and build labels' {
            Format-NuGetPackageVersion -Version '1.2.3-rc1+20231225' | Should -Be '1.2.3-rc1+20231225'
        }
        It 'should concatenate pre-release and build labels for SemVer 1.0.0' {
            Format-NuGetPackageVersion -Version '1.2.3-rc1+20231225' -SemanticVersion '1.0.0' |
                Should -Be '1.2.3-rc120231225'
        }
        It 'should return the clean version for SemVer 1.0.0 with no labels' {
            Format-NuGetPackageVersion -Version '1.2.3' -SemanticVersion '1.0.0' | Should -Be '1.2.3'
        }
        It 'should truncate combined pre-release labels longer than 20 characters for SemVer 1.0.0' {
            $Result = Format-NuGetPackageVersion -Version '1.0.0-abcdefghij1234567890extra' -SemanticVersion '1.0.0'
            $PreRelease = $Result -replace '^[0-9]+\.[0-9]+\.[0-9]+-', ''
            $PreRelease.Length | Should -Be 20
        }
    }

    Context 'Update-Version' {
        It 'should increment the patch version' {
            Update-Version -Version '1.2.3' -ReleaseType 'patch' | Should -Be '1.2.4'
        }
        It 'should increment the minor version and reset the patch' {
            Update-Version -Version '1.2.3' -ReleaseType 'minor' | Should -Be '1.3.0'
        }
        It 'should increment the major version and reset minor and patch' {
            Update-Version -Version '1.2.3' -ReleaseType 'major' | Should -Be '2.0.0'
        }
        It 'should append a pre-release string when specified' {
            Update-Version -Version '1.2.3' -ReleaseType 'patch' -PreReleaseString 'alpha' |
                Should -Be '1.2.4-alpha'
        }
        It 'should append a build number when specified' {
            Update-Version -Version '1.2.3' -ReleaseType 'patch' -BuildNumber '20231225' |
                Should -Be '1.2.4+20231225'
        }
    }

    Context 'Read-BrownserveChangelog' {
        BeforeAll {
            $script:ChangelogPath = Join-Path $TestDrive 'CHANGELOG.md'
            $Lines = @(
                '# Changelog',
                '',
                '## [v1.2.0](https://github.com/org/repo/releases/tag/v1.2.0) (2024-01-15)',
                '',
                '### Added',
                '',
                '- Feature A',
                '',
                '## [v1.1.0](https://github.com/org/repo/releases/tag/v1.1.0) (2023-11-20)',
                '',
                '### Added',
                '',
                '- Feature B'
            )
            Set-Content -Path $script:ChangelogPath -Value $Lines
        }
        It 'should return a non-null changelog object' {
            $Result = Read-BrownserveChangelog -ChangelogPath $script:ChangelogPath
            $Result | Should -Not -BeNullOrEmpty
        }
        It 'should parse the correct number of versions' {
            $Result = Read-BrownserveChangelog -ChangelogPath $script:ChangelogPath
            $Result.VersionHistory.Count | Should -Be 2
        }
        It 'should return versions sorted with the most recent first' {
            $Result = Read-BrownserveChangelog -ChangelogPath $script:ChangelogPath
            $Result.VersionHistory[0].Version.ToString() | Should -Be '1.2.0'
            $Result.VersionHistory[1].Version.ToString() | Should -Be '1.1.0'
        }
        It 'should identify the latest version correctly' {
            $Result = Read-BrownserveChangelog -ChangelogPath $script:ChangelogPath
            $Result.LatestVersion.Version.ToString() | Should -Be '1.2.0'
        }
    }
}
