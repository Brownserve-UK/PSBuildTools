@{
    'PowerShellModule'              = @{
        ContributingTemplate       = 'PowerShellModule_github_contributing.md.template'
        PRTemplateTemplate         = 'PowerShellModule_github_pull_request_template.md.template'
        PRTemplateSubstitutionKeys = @('MODULE_NAME', 'OWNER')
        PesterTests                = @(
            @{ FileName = 'Help.Tests.ps1'; TemplateName = 'help.tests.ps1.template'; SubstitutionKeys = @('MODULE_NAME') }
        )
    }
    'RustBinary'                    = @{
        WorkflowTemplates          = @{
            Builds       = 'rustapp_github_builds.yaml.template'
            StageRelease = 'rustapp_github_stage-release.yaml.template'
            Release      = 'rustapp_github_release.yaml.template'
        }
        ContributingTemplate       = 'RustApp_github_contributing.md.template'
        PRTemplateTemplate         = 'RustApp_github_pull_request_template.md.template'
        PRTemplateSubstitutionKeys = @('REPO_NAME', 'OWNER')
        PesterTests                = @(
            @{ FileName = 'Basic.Binary.Tests.ps1'; TemplateName = 'rustapp_binary_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
    'ContainerImage'                = @{
        WorkflowTemplates          = @{
            Builds       = 'webapp_github_builds.yaml.template'
            StageRelease = 'webapp_github_stage-release.yaml.template'
            Release      = 'webapp_github_release.yaml.template'
        }
        ContributingTemplate       = 'WebApp_github_contributing.md.template'
        PRTemplateTemplate         = 'WebApp_github_pull_request_template.md.template'
        PRTemplateSubstitutionKeys = @('REPO_NAME', 'OWNER')
        PesterTests                = @(
            @{ FileName = 'Basic.Container.Tests.ps1'; TemplateName = 'container_basic_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
    'ContainerImage+RustBinary'     = @{
        WorkflowTemplates          = @{
            Builds       = 'bsdev_github_builds.yaml.template'
            StageRelease = 'rustapp_github_stage-release.yaml.template'
            Release      = 'bsdev_github_release.yaml.template'
        }
        ContributingTemplate       = 'RustApp_github_contributing.md.template'
        PRTemplateTemplate         = 'RustApp_github_pull_request_template.md.template'
        PRTemplateSubstitutionKeys = @('REPO_NAME', 'OWNER')
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
        WorkflowTemplates          = @{
            Builds       = 'skillsrepo_github_builds.yaml.template'
            StageRelease = 'webapp_github_stage-release.yaml.template'
            Release      = 'skillsrepo_github_release.yaml.template'
        }
        ContributingTemplate       = 'SkillsRepo_github_contributing.md.template'
        PRTemplateTemplate         = 'SkillsRepo_github_pull_request_template.md.template'
        PRTemplateSubstitutionKeys = @('REPO_NAME', 'OWNER')
        PesterTests                = @(
            @{ FileName = 'Skills.Tests.ps1'; TemplateName = 'skillsrepo_skills_tests.ps1.template'; SubstitutionKeys = @('REPO_NAME') }
        )
    }
}
