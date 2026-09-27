@{
    Requires = @()
    Options  = @()
    Data     = @{
        GitIgnores          = @(
            @{
                Comment = 'Paket is used to restore various dependencies (including the Brownserve.PSTools PowerShell module).`nWe deliberately ignore the ''paket.lock'' file as our projects are usually not precious about taking the latest versions of packages.'
                Item    = @('paket.lock', 'packages/', 'paket-files/')
            }
            @{
                Comment = 'The temporary directory is used to store build output, log files, redirected output etc. It is recreated by the _init.ps1 script.'
                Item    = '.tmp/'
            }
            @{
                Comment = 'AI coding tool directories contain local/personal configuration and session data that should not be committed.'
                Item    = @('.agents/*', '!.agents/project.json', '.claude/', '.cursor/', '.aider*', '.continue/')
            }
        )
        PaketDependencies   = @(
            @{
                Comment = 'Brownserve modules used to build and test this module'
                Rule    = @(
                    @{ PackageName = 'Brownserve.PSCommon'; Source = 'nuget' }
                    @{ PackageName = 'Brownserve.PSSourceControl'; Source = 'nuget' }
                    @{ PackageName = 'Brownserve.PSBuildTools'; Source = 'nuget' }
                )
            }
            @{
                Comment = 'Invoke-Build is used to run our builds'
                Rule    = @(
                    @{ Source = 'nuget'; PackageName = 'Invoke-Build' }
                )
            }
        )
        PermanentPaths      = @(
            @{
                VariableName = 'BrownserveRepoBuildDirectory'
                Path         = '.build'
                Description  = 'Contains build configuration along with this _init.ps1 script'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoBuildTasksDirectory'
                Path         = '.build'
                ChildPaths   = 'tasks'
                Description  = 'Stores any tasks that we pass to Invoke-Build'
                PathType     = 'Directory'
            }
        )
        EphemeralPaths      = @(
            @{
                VariableName = 'BrownserveRepoTempDirectory'
                Path         = '.tmp'
                Description  = 'Used to store temporary files created for builds/tests'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoLogDirectory'
                Path         = '.tmp'
                ChildPaths   = 'logs'
                Description  = 'Used to store build logs, output from Invoke-NativeCommand and the like'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoBuildOutputDirectory'
                Path         = '.tmp'
                ChildPaths   = 'output'
                Description  = 'Used to store any output from builds (e.g. Terraform plans, MSBuild artifacts etc)'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoBinaryDirectory'
                Path         = '.tmp'
                ChildPaths   = 'bin'
                Description  = 'Used to store any downloaded/copied binaries required for builds, cmdlets like Get-Vault make use of this variable'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoNugetPackagesDirectory'
                Path         = 'packages'
                Description  = 'Paket/nuget will restore their dependencies to this directory, case sensitive on Linux'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownserveRepoPaketFilesDirectory'
                Path         = 'paket-files'
                Description  = 'Paket will restore certain types of dependencies to this directory, case sensitive on Linux'
                PathType     = 'Directory'
            }
            @{
                VariableName = 'BrownservePaketLockFile'
                Path         = 'paket.lock'
                Description  = 'We deliberately regenerate this every time because we live on the edge and always take the latest versions of our packages.'
                PathType     = 'File'
            }
        )
        VSCodeExtensions    = @(
            @{
                ExtensionID    = 'streetsidesoftware.code-spell-checker'
                CustomSettings = @{
                    'cSpell.language' = 'en,en-GB'
                    'cSpell.words'    = @('Brownserve', 'paket', 'Teamcity', 'TMPDIR', 'Choco', 'CICD', 'dedupe', 'devcontainer', 'mrkdwn', 'nugetconfig', 'nupkg', 'yzhang')
                }
            }
        )
        PackageAliases      = @()
        EditorConfig        = @(
            @{
                Comment    = 'Default for all files unless overridden by another rule'
                FilePath   = '*'
                Properties = @(
                    @{ Name = 'end_of_line'; Value = 'lf' }
                    @{ Name = 'indent_style'; Value = 'space' }
                    @{ Name = 'indent_size'; Value = 2 }
                    @{ Name = 'insert_final_newline'; Value = $true }
                )
            }
        )
    }
}
