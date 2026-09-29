@{
    'PowerShellModule'              = @{
        PesterTests                = @(
            @{ FileName = 'Help.Tests.ps1'; TemplateName = 'help.tests.ps1.template'; SubstitutionKeys = @('MODULE_NAME') }
        )
    }
    'RustBinary'                    = @{
        PesterTests                = @(
            @{ FileName = 'Basic.Binary.Tests.ps1'; TemplateName = 'rustapp_binary_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
    'ContainerImage'                = @{
        PesterTests                = @(
            @{ FileName = 'Basic.Container.Tests.ps1'; TemplateName = 'container_basic_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
    'ContainerImage+RustBinary'     = @{
        PesterTests                = @(
            @{ FileName = 'Basic.Binary.Tests.ps1'; TemplateName = 'rustapp_binary_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
        VSCodeExtensionsOverride   = @(
            @{ ExtensionID = 'rust-lang.rust-analyzer'; CustomSettings = @{} }
            @{ ExtensionID = 'tamasfe.even-better-toml'; CustomSettings = @{} }
            @{ ExtensionID = 'ms-azuretools.vscode-docker'; CustomSettings = @{} }
            @{
                ExtensionID    = 'ms-vscode.powershell'
                CustomSettings = @{
                    'powershell.helpCompletion'                          = 'Disabled'
                    'powershell.codeFormatting.trimWhitespaceAroundPipe' = $true
                    'powershell.codeFormatting.useConstantStrings'       = $true
                    'powershell.codeFormatting.autoCorrectAliases'       = $true
                    'powershell.codeFormatting.pipelineIndentationStyle' = 'IncreaseIndentationAfterEveryPipeline'
                    'powershell.codeFormatting.preset'                   = 'Allman'
                    'powershell.codeFormatting.useCorrectCasing'         = $true
                }
            }
            @{ ExtensionID = 'EditorConfig.EditorConfig'; CustomSettings = @{} }
            @{ ExtensionID = 'DavidAnson.vscode-markdownlint'; CustomSettings = @{} }
        )
    }
    'DirectoryArchive'              = @{
        PesterTests                = @(
            @{ FileName = 'Skills.Tests.ps1'; TemplateName = 'skillsrepo_skills_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
}
