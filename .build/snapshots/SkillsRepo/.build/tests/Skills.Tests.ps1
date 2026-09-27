#requires -Modules Pester
BeforeDiscovery {
    $script:Skills = Get-ChildItem -Path $Global:BrownserveRepoSkillsDirectory -Directory | ForEach-Object {
        @{ SkillName = $_.Name; SkillPath = $_.FullName }
    }
}

Describe 'test-skills-repo skills' {
    Context 'Skill <SkillName>' -ForEach $script:Skills {
        BeforeAll {
            $script:SkillFile = Join-Path $SkillPath 'SKILL.md'
            $script:Frontmatter = $null
            if (Test-Path $script:SkillFile)
            {
                $Content = Get-Content -Path $script:SkillFile -Raw
                if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---')
                {
                    $script:Frontmatter = $Matches[1]
                }
            }
        }

        It 'should contain a SKILL.md' {
            $script:SkillFile | Should -Exist
        }

        It 'should have frontmatter' {
            $script:Frontmatter | Should -Not -BeNullOrEmpty
        }

        It 'should have a name that matches the directory' {
            $script:Frontmatter | Should -Match "(?m)^name:\s*['""]?$([regex]::Escape($SkillName))['""]?\s*$"
        }

        It 'should have a description' {
            $script:Frontmatter | Should -Match '(?m)^description:'
        }
    }
}
